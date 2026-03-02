from setuptools import setup, find_packages
setup(
    name="nullsec-imp",
    version="1.0.0",
    description="😈 Shell History Auditor — mischievous demons in your command history",
    author="bad-antics",
    author_email="nullsec@proton.me",
    license="MIT",
    packages=find_packages(),
    install_requires=["click>=8.0"],
    entry_points={"console_scripts": ["imp=imp.cli:entry_point"]},
    python_requires=">=3.8",
)
