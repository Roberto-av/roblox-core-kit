"""Verifica que el paquete se consuma correctamente como dependencia externa.

Pasos:
  1. `wally package` sobre el estado actual del repositorio y comprobación de su contenido.
  2. Proyecto consumidor vacío en una carpeta temporal con `wally install` real de las dependencias.
  3. El paquete se coloca con la disposición que usa Wally (_Index/<scope>_<nombre>@<version>/).
  4. `rojo build` del consumidor y resolución estática de todos los require() del paquete
     sobre el sourcemap de Rojo.

Limitaciones: no ejecuta Luau; comprueba rutas y compilación. La prueba real final es
`wally publish` seguido de `wally install` en un proyecto nuevo.

Requisitos: Python 3.8+, y wally y rojo disponibles (rokit install).
Uso: python scripts/verify-package.py [--keep]
"""

import argparse
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import zipfile

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# Contenido permitido del paquete publicado (archivos exactos o prefijos de carpeta).
ALLOWED_FILES = {"default.project.json", "README.md", "LICENSE", "CHANGELOG.md", "wally.toml"}
ALLOWED_DIRS = ("src/",)
ALLOWED_DOCS = {"docs/ARCHITECTURE.md", "docs/API_REFERENCE.md"}

failures = []


def check(ok, message):
    print(("[OK]    " if ok else "[FALLO] ") + message)
    if not ok:
        failures.append(message)
    return ok


def run(cmd, cwd):
    result = subprocess.run(cmd, cwd=cwd, capture_output=True, text=True, shell=(os.name == "nt"))
    return result.returncode, (result.stdout + result.stderr).strip()


def read_manifest():
    text = open(os.path.join(REPO, "wally.toml"), encoding="utf-8").read()
    name = re.search(r'^name\s*=\s*"([^"]+)"', text, re.M).group(1)
    version = re.search(r'^version\s*=\s*"([^"]+)"', text, re.M).group(1)
    deps = dict(re.findall(r'^(\w+)\s*=\s*"([^"]+@[^"]+)"', text.split("[dependencies]")[1], re.M))
    return name, version, deps


def package_step(workdir):
    archive = os.path.join(workdir, "package.zip")
    code, out = run(["wally", "package", "--output", archive], REPO)
    if not check(code == 0, "wally package"):
        print(out)
        return None
    extract = os.path.join(workdir, "package")
    with zipfile.ZipFile(archive) as z:
        names = [i.filename for i in z.infolist() if not i.filename.endswith("/")]
        z.extractall(extract)
    unexpected = [
        n for n in names if n not in ALLOWED_FILES and n not in ALLOWED_DOCS and not n.startswith(ALLOWED_DIRS)
    ]
    check(not unexpected, f"el paquete solo contiene archivos permitidos (sobran: {unexpected})")
    missing = [f for f in sorted(ALLOWED_FILES | ALLOWED_DOCS) if f not in names]
    check(not missing, f"el paquete incluye lo esperado (faltan: {missing})")
    return extract


def build_consumer(workdir, package_dir, name, version, deps):
    consumer = os.path.join(workdir, "consumer")
    os.makedirs(os.path.join(consumer, "client"))
    shutil.copy(os.path.join(REPO, "rokit.toml"), consumer)  # para que rokit encuentre wally y rojo

    dependencies = "\n".join(f'{key} = "{value}"' for key, value in deps.items())
    open(os.path.join(consumer, "wally.toml"), "w", encoding="utf-8").write(
        '[package]\nname = "tester/consumer"\nversion = "0.1.0"\n'
        'registry = "https://github.com/UpliftGames/wally-index"\nrealm = "shared"\n\n'
        f"[dependencies]\n{dependencies}\n"
    )
    code, out = run(["wally", "install"], consumer)
    if not check(code == 0, "wally install de las dependencias en un proyecto vacío"):
        print(out)
        return None

    # Nombre real de cada dependencia instalada: _Index/<scope>_<nombre>@<version>/<nombre>
    index = os.path.join(consumer, "Packages", "_Index")
    installed = {}
    for folder in os.listdir(index):
        inner = os.listdir(os.path.join(index, folder))
        if inner:
            installed[folder] = inner[0]

    scope, package = name.split("/")
    pkg_folder = f"{scope}_{package}@{version}"
    pkg_root = os.path.join(index, pkg_folder)
    shutil.copytree(package_dir, os.path.join(pkg_root, package))
    for key in deps:
        # Wally enlaza cada dependencia como hermana del paquete
        match = [(f, i) for f, i in installed.items() if f.split("@")[0].split("_", 1)[1].lower() == key.lower()
                 or i.lower() == key.lower()]
        if not match:
            check(False, f"dependencia {key} instalada")
            continue
        folder, inner = match[0]
        link = f'return require(script.Parent.Parent["{folder}"]["{inner}"])\n'
        open(os.path.join(pkg_root, f"{key}.lua"), "w", encoding="utf-8").write(link)
    open(os.path.join(consumer, "Packages", "CoreKit.lua"), "w", encoding="utf-8").write(
        f'return require(script.Parent._Index["{pkg_folder}"]["{package}"])\n'
    )
    open(os.path.join(consumer, "default.project.json"), "w", encoding="utf-8").write(
        json.dumps(
            {
                "name": "consumer",
                "tree": {
                    "$className": "DataModel",
                    "ReplicatedStorage": {"Packages": {"$path": "Packages"}},
                    "StarterPlayer": {"StarterPlayerScripts": {"$className": "Folder", "$path": "client"}},
                },
            },
            indent=2,
        )
    )
    open(os.path.join(consumer, "client", "Main.client.luau"), "w", encoding="utf-8").write(
        'local CoreKit = game:GetService("ReplicatedStorage").Packages.CoreKit\n'
        'local UiRouter = require(CoreKit.UiRouter)\nUiRouter:Init()\n'
    )
    return consumer, pkg_folder, package


TOKEN = re.compile(r'\.Parent|\.([A-Za-z_]\w*)|\["([^"]+)"\]')


def index_tree(node, parent=None):
    node["_parent"] = parent
    for child in node.get("children", []):
        index_tree(child, node)


def walk(node, chain):
    pos = 0
    while pos < len(chain):
        m = TOKEN.match(chain, pos)
        if not m:
            raise ValueError(f"cadena no soportada: {chain[pos:]}")
        if m.group(0) == ".Parent":
            node = node["_parent"]
        else:
            name = m.group(1) or m.group(2)
            found = [c for c in node.get("children", []) if c["name"] == name]
            if not found:
                raise LookupError(f"'{name}' no existe bajo '{node['name']}'")
            node = found[0]
        pos = m.end()
    return node


def resolve_requires(consumer, pkg_folder):
    sourcemap = os.path.join(consumer, "sourcemap.json")
    code, out = run(["rojo", "sourcemap", "default.project.json", "-o", sourcemap], consumer)
    if not check(code == 0, "rojo sourcemap del consumidor"):
        print(out)
        return
    tree = json.load(open(sourcemap, encoding="utf-8"))
    index_tree(tree)
    by_file = {}

    def collect(node):
        for path in node.get("filePaths", []):
            by_file[os.path.normcase(os.path.normpath(os.path.join(consumer, path)))] = node
        for child in node.get("children", []):
            collect(child)

    collect(tree)

    checked, errors = 0, []
    root = os.path.join(consumer, "Packages", "_Index", pkg_folder)
    for dirpath, _, files in os.walk(root):
        for filename in files:
            if not filename.endswith((".luau", ".lua")):
                continue
            path = os.path.join(dirpath, filename)
            node = by_file.get(os.path.normcase(os.path.normpath(path)))
            if node is None:
                continue
            variables = {}
            for line in open(path, encoding="utf-8"):
                assign = re.match(r"\s*local (\w+)(?:: \w+)? = (.+)$", line.rstrip())
                if assign and "require(" not in assign.group(2):
                    head = re.match(r"\(?\s*(\w+)(.*)", re.sub(r"\s*::\s*\w+", "", assign.group(2)))
                    base = node if head and head.group(1) == "script" else variables.get(head.group(1)) if head else None
                    if base is not None:
                        try:
                            variables[assign.group(1)] = walk(base, head.group(2).strip().rstrip(")"))
                        except Exception:
                            pass
                for req in re.finditer(r"require\(([^)]*)\)", line):
                    expr = re.sub(r"\s*::\s*\w+", "", req.group(1)).strip()
                    head = re.match(r"(\w+)(.*)", expr)
                    if not head or head.group(1) not in ("script", *variables):
                        continue  # p. ej. un ModuleScript guardado en una variable (require diferido)
                    checked += 1
                    base = node if head.group(1) == "script" else variables[head.group(1)]
                    try:
                        target = walk(base, head.group(2))
                        if target.get("className") != "ModuleScript":
                            raise LookupError(f"no es un ModuleScript ({target.get('className')})")
                    except Exception as exc:
                        errors.append(f"{os.path.relpath(path, root)}: require({expr}) -> {exc}")
    check(checked > 0 and not errors, f"require() resueltos en el consumidor ({checked} comprobados)")
    for error in errors:
        print("          " + error)

    # require diferido de ConfirmDialog desde UiRouter (se resuelve en tiempo de ejecución)
    package_node = walk(tree, f'["ReplicatedStorage"]["Packages"]["_Index"]["{pkg_folder}"]')
    target = [c for c in package_node["children"] if c["className"] == "ModuleScript"]
    kit = next((c for c in target if c["name"] not in ("Iris", "Signal")), None)
    try:
        walk(kit, '["Components"]["ConfirmDialog"]')
        check(True, "ConfirmDialog accesible para el require diferido de UiRouter")
    except Exception as exc:
        check(False, f"ConfirmDialog accesible para el require diferido de UiRouter ({exc})")


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--keep", action="store_true", help="conserva la carpeta temporal")
    args = parser.parse_args()
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8")

    name, version, deps = read_manifest()
    workdir = tempfile.mkdtemp(prefix="corekit-verify-")
    try:
        package_dir = package_step(workdir)
        if package_dir:
            built = build_consumer(workdir, package_dir, name, version, deps)
            if built:
                consumer, pkg_folder, _ = built
                code, out = run(["rojo", "build", "default.project.json", "-o", "consumer.rbxl"], consumer)
                if check(code == 0, "rojo build del proyecto consumidor"):
                    resolve_requires(consumer, pkg_folder)
                else:
                    print(out)
    finally:
        if args.keep:
            print(f"Carpeta temporal conservada: {workdir}")
        else:
            shutil.rmtree(workdir, ignore_errors=True)

    print("\nRESULTADO: " + ("TODO OK" if not failures else f"{len(failures)} fallo(s)"))
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
