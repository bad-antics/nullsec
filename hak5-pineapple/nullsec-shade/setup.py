from setuptools import setup, find_packages
setup(
    name="nullsec-shade",
    version="1.0.0",
    description="🌑 File Permission Anomaly Hunter — darkness hides in your permissions",
    author="bad-antics",
    author_email="nullsec@proton.me",
    license="MIT",
    packages=find_packages(),
    install_requires=["click>=8.0"],
    entry_points={"console_scripts": ["shade=shade.cli:entry_point"]},
    python_requires=">=3.8",
)
