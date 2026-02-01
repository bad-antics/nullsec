# NullSec Enhanced Interactive Framework

## Overview
The NullSec framework now features an advanced interactive module system that provides rich parameter collection, validation, and user-friendly interfaces for all attack modules.

## Features

### Rich Parameter Types
- **String**: Free-form text input
- **IP**: IP address with validation
- **Port**: Port number (1-65535) validation
- **File**: File path with existence checking
- **Choice**: Multiple choice selection (numeric or text)
- **Boolean**: Yes/No questions
- **List**: Comma-separated values
- **Domain**: Domain name input
- **URL**: URL validation

### Interactive Elements
- ✅ Real-time input validation
- ✅ Default value suggestions
- ✅ Help text and descriptions
- ✅ Multiple choice menus
- ✅ Parameter summary before execution
- ✅ Prerequisite checking
- ✅ Progress indicators
- ✅ Colored output for better readability

## Creating Enhanced Modules

### 1. Create Module Script
Standard bash script in `nullsecurity/` directory that reads from environment variables:

```bash
#!/bin/bash
# Read parameters from NULLSEC_* environment variables
TARGET="${NULLSEC_TARGET}"
PORT="${NULLSEC_PORT}"
ATTACK_TYPE="${NULLSEC_ATTACK_TYPE}"

# Your attack code here
```

### 2. Create JSON Configuration
Create a `.json` file with the same base name as your script:

```json
{
  "name": "My Attack Module",
  "description": "Description of what this module does",
  "category": "Exploitation",
  "requires_root": false,
  "pre_run_checks": ["nmap", "metasploit"],
  "parameters": [
    {
      "name": "target",
      "prompt": "Target IP Address",
      "param_type": "ip",
      "required": true,
      "description": "IP address of the target system"
    },
    {
      "name": "attack_type",
      "prompt": "Select Attack Method",
      "param_type": "choice",
      "required": true,
      "choices": ["Fast Scan", "Stealth Scan", "Full Scan"],
      "description": "Type of scan to perform"
    },
    {
      "name": "port",
      "prompt": "Target Port",
      "param_type": "port",
      "required": false,
      "default": "443",
      "description": "Service port number"
    }
  ],
  "examples": [
    {"desc": "Example 1: Fast vulnerability scan"},
    {"desc": "Example 2: Stealth reconnaissance"}
  ]
}
```

### 3. Parameter Types Reference

#### Required Fields
- `name`: Variable name (becomes NULLSEC_NAME in environment)
- `prompt`: What to ask the user
- `param_type`: Type of validation to apply
- `required`: true/false

#### Optional Fields
- `default`: Default value if user presses Enter
- `choices`: Array of options for choice type
- `description`: Help text shown to user

## Usage

### From NullSec Launcher
The framework automatically detects if a `.json` config exists for a module and uses the enhanced interface.

### Direct Execution
```bash
python3 module-framework.py <script.sh> <config.json>
```

### Environment Variables
All parameters are passed to scripts as environment variables:
- Parameter `target` → `NULLSEC_TARGET`
- Parameter `attack_type` → `NULLSEC_ATTACK_TYPE`
- etc.

## Example: Enhanced AD Attack

```bash
# Launch from NullSec menu - automatically uses enhanced mode
./nullsec-launcher.py
# Select Active Directory Attack module
```

The module will:
1. Show description and examples
2. Check prerequisites
3. Interactively collect:
   - Attack vector (choice from 8 options)
   - Domain controller IP
   - Domain name
   - Optional credentials
   - Stealth mode preference
   - Output format
   - Timeout value
4. Display summary
5. Confirm before execution
6. Pass all params as environment variables
7. Execute with beautiful progress indicators

## Converting Existing Modules

1. Identify all `read -p` prompts in your bash script
2. Replace with environment variable reads: `${NULLSEC_VARNAME}`
3. Create matching JSON config with same parameters
4. Test with `python3 module-framework.py script.sh config.json`

## Benefits

- **User Experience**: Much more professional and user-friendly
- **Validation**: Catch errors before execution
- **Documentation**: JSON configs serve as documentation
- **Consistency**: All modules have same look and feel
- **Efficiency**: Faster data entry with choices and defaults
- **Safety**: Confirmation before destructive operations
