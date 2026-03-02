from setuptools import setup, find_packages
setup(
    name="nullsec-ouija", version="1.0.0",
    description="Summon Spirits From Deleted Files — File Carving & Recovery",
    long_description=open("README.md").read(), long_description_content_type="text/markdown",
    author="bad-antics", author_email="nullsec@proton.me",
    packages=find_packages(), python_requires=">=3.8",
    install_requires=["click>=8.0"],
    entry_points={"console_scripts": ["ouija=ouija.cli:entry_point"]},
)
