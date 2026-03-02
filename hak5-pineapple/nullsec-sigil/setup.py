from setuptools import setup, find_packages

setup(
    name="nullsec-sigil",
    version="1.0.0",
    description="Visual Hash Fingerprinting — Turn any hash into unique geometric SVG art",
    long_description=open("README.md").read(),
    long_description_content_type="text/markdown",
    author="bad-antics",
    author_email="nullsec@proton.me",
    url="https://github.com/bad-antics/nullsec-sigil",
    packages=find_packages(),
    python_requires=">=3.8",
    install_requires=["click>=8.0"],
    extras_require={"png": ["cairosvg>=2.5"]},
    entry_points={
        "console_scripts": [
            "sigil=sigil.cli:entry_point",
        ],
    },
    classifiers=[
        "Development Status :: 4 - Beta",
        "Environment :: Console",
        "Intended Audience :: Developers",
        "Intended Audience :: Information Technology",
        "License :: OSI Approved :: MIT License",
        "Programming Language :: Python :: 3",
        "Topic :: Security",
        "Topic :: Artistic Software",
    ],
)
