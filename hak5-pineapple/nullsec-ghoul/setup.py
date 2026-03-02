from setuptools import setup, find_packages
setup(
    name="nullsec-ghoul",
    version="1.0.0",
    description="👹 Shared Library Injection Detector — find .so parasites in your processes",
    author="bad-antics",
    author_email="nullsec@proton.me",
    license="MIT",
    packages=find_packages(),
    install_requires=["click>=8.0"],
    entry_points={"console_scripts": ["ghoul=ghoul.cli:entry_point"]},
    python_requires=">=3.8",
)
