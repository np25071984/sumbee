"""Checks every listing field against its store limit: python3 design/store/listings/check.py"""
import pathlib, re, sys

failed = False
for path in sorted(pathlib.Path(__file__).parent.glob("*.md")):
    if path.name == "README.md":
        continue
    for heading, body in re.findall(r"^## (.+?)\n(.*?)(?=^## |\Z)", path.read_text(), flags=re.S | re.M):
        limit = int(re.search(r"\((\d+)", heading).group(1))
        text = body.strip()
        problems = []
        if len(text) > limit:
            problems.append(f"{len(text)} > {limit}")
        if "keywords" in heading and (", " in text or " ," in text):
            problems.append("space after a comma")
        status = "FAIL " + ", ".join(problems) if problems else "ok"
        failed |= bool(problems)
        print(f"{path.stem}  {heading:<34} {len(text):>4}/{limit:<4} {status}")
sys.exit(failed)
