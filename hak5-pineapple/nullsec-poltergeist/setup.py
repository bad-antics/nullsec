from setuptools import setup, find_packages
setup(
    name="nullsec-poltergeist", version="1.0.0",
    description="Filesystem Chaos Agent — Anomaly Detection & Honeypots",
    long_description=open("README.md").read(), long_description_content_type="text/markdown",
    author="bad-antics", author_email="nullsec@proton.me",
    packages=find_packages(), python_requires=">=3.8",
    install_requires=["click>=8.0"],
    entry_points={"console_scripts": ["poltergeist=poltergeist.cli:entry_point"]},
)
