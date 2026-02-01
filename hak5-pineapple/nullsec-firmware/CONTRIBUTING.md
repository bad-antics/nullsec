# Contributing to NullSec Firmware

Thank you for your interest in contributing to the NullSec Firmware project!

## Code of Conduct

- Be respectful and inclusive
- Focus on constructive feedback
- Help others learn and grow

## How to Contribute

### Reporting Bugs

1. Check existing issues first
2. Use the bug report template
3. Include:
   - Device model and firmware version
   - Steps to reproduce
   - Expected vs actual behavior
   - Relevant logs or screenshots

### Suggesting Features

1. Check if the feature already exists or is planned
2. Use the feature request template
3. Explain the use case and benefits

### Submitting Payloads

We welcome new payload contributions! Here's how:

1. **Fork the repository**

2. **Create your payload** following our guidelines:
   - Include header with description and credits
   - Add `# Credits: Built for Hak5 WiFi Pineapple - https://hak5.org`
   - Use consistent variable naming
   - Add comprehensive comments
   - Include usage documentation

3. **Test thoroughly**
   - Test on actual Pineapple Pager hardware
   - Verify all options work correctly
   - Check for edge cases

4. **Submit a pull request**
   - Use descriptive commit messages
   - Reference any related issues
   - Include test results

### Payload Template

```bash
#!/bin/bash
#═══════════════════════════════════════════════════════════════════════════════
# [Payload Name]
# [Brief description of what it does]
#
# For authorized security testing only!
# Credits: Built for Hak5 WiFi Pineapple - https://hak5.org
#═══════════════════════════════════════════════════════════════════════════════

VERSION="1.0"
LOOT_DIR="/mmc/nullsec/[category]"

# Your code here...
```

### Theme Contributions

If you want to contribute theme modifications:

1. Test all UI elements
2. Ensure readability
3. Include preview screenshots
4. Document color palette

## Development Setup

```bash
# Clone the repository
git clone https://github.com/nullsec/pineapple-firmware
cd pineapple-firmware

# Create feature branch
git checkout -b feature/my-new-payload

# Make your changes
# ...

# Test on device
./tools/deploy-to-pager.sh

# Commit and push
git add .
git commit -m "Add: my new payload description"
git push origin feature/my-new-payload
```

## Pull Request Process

1. Update documentation if needed
2. Add entry to CHANGELOG.md
3. Ensure CI checks pass
4. Request review from maintainers

## Style Guidelines

### Shell Scripts

- Use `#!/bin/bash` shebang
- Use 4-space indentation
- Quote variables: `"$var"` not `$var`
- Use `[[ ]]` for conditionals
- Add error handling

### Documentation

- Use Markdown format
- Include code examples
- Add screenshots where helpful
- Keep language clear and concise

## Recognition

Contributors will be:
- Listed in CONTRIBUTORS.md
- Credited in relevant payloads
- Thanked in release notes

## Questions?

- Open a GitHub Discussion
- Join our Discord server
- Check the FAQ in the wiki

---

**Thank you for contributing to the security community!**

*Built for Hak5 WiFi Pineapple - https://hak5.org*
