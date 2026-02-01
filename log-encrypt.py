#!/usr/bin/env python3
"""
NullSec Linux - Log Encryption Utility v1.2
Encrypts sensitive logs using AES-256 encryption via Fernet.
Supports password-based key derivation with PBKDF2-HMAC-SHA256.

GitHub: https://github.com/bad-antics/nullsec
"""

__version__ = "1.2"
__author__ = "bad-antics"

import os
import sys
import json
import base64
import getpass
import hashlib
from pathlib import Path
from datetime import datetime
from cryptography.fernet import Fernet
from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.primitives.kdf.pbkdf2 import PBKDF2HMAC
from cryptography.hazmat.backends import default_backend

class LogEncryption:
    """Handle encryption/decryption of log files"""
    
    def __init__(self, key_file=None):
        self.key_file = key_file or os.path.expanduser("~/.nullsec/encryption.key")
        self.salt_file = os.path.expanduser("~/.nullsec/encryption.salt")
        self._ensure_key_directory()
    
    def _ensure_key_directory(self):
        """Create encryption key directory"""
        key_dir = os.path.dirname(self.key_file)
        os.makedirs(key_dir, mode=0o700, exist_ok=True)
    
    def _derive_key(self, password, salt):
        """Derive encryption key from password"""
        kdf = PBKDF2HMAC(
            algorithm=hashes.SHA256(),
            length=32,
            salt=salt,
            iterations=100000,
            backend=default_backend()
        )
        return base64.urlsafe_b64encode(kdf.derive(password.encode()))
    
    def generate_key(self, password=None):
        """Generate new encryption key"""
        if password is None:
            password = getpass.getpass("Enter encryption password: ")
            password2 = getpass.getpass("Confirm password: ")
            
            if password != password2:
                raise ValueError("Passwords do not match")
        
        # Generate random salt
        salt = os.urandom(16)
        
        # Derive key from password
        key = self._derive_key(password, salt)
        
        # Save salt
        with open(self.salt_file, 'wb') as f:
            f.write(salt)
        os.chmod(self.salt_file, 0o600)
        
        # Save key (encrypted with password)
        with open(self.key_file, 'wb') as f:
            f.write(key)
        os.chmod(self.key_file, 0o600)
        
        print(f"[+] Encryption key generated and saved to {self.key_file}")
        return key
    
    def load_key(self, password=None):
        """Load encryption key"""
        if not os.path.exists(self.key_file) or not os.path.exists(self.salt_file):
            if password:
                return self.generate_key(password)
            else:
                raise FileNotFoundError("Encryption key not found. Run with --generate-key first.")
        
        # Load salt
        with open(self.salt_file, 'rb') as f:
            salt = f.read()
        
        # Get password if not provided
        if password is None:
            password = getpass.getpass("Enter encryption password: ")
        
        # Derive key
        key = self._derive_key(password, salt)
        
        # Verify key matches
        with open(self.key_file, 'rb') as f:
            stored_key = f.read()
        
        if key != stored_key:
            raise ValueError("Incorrect password")
        
        return key
    
    def encrypt_file(self, filepath, output_path=None, password=None):
        """Encrypt a log file"""
        try:
            key = self.load_key(password)
            fernet = Fernet(key)
            
            # Read file content
            with open(filepath, 'rb') as f:
                data = f.read()
            
            # Encrypt
            encrypted = fernet.encrypt(data)
            
            # Determine output path
            if output_path is None:
                output_path = filepath + '.enc'
            
            # Write encrypted file
            with open(output_path, 'wb') as f:
                f.write(encrypted)
            
            # Create metadata
            metadata = {
                'original_file': os.path.basename(filepath),
                'encrypted_at': datetime.now().isoformat(),
                'size_original': len(data),
                'size_encrypted': len(encrypted)
            }
            
            metadata_path = output_path + '.meta'
            with open(metadata_path, 'w') as f:
                json.dump(metadata, f, indent=2)
            
            print(f"[+] Encrypted: {filepath} -> {output_path}")
            print(f"    Original size: {len(data)} bytes")
            print(f"    Encrypted size: {len(encrypted)} bytes")
            
            return output_path
            
        except Exception as e:
            print(f"[-] Encryption failed: {e}")
            return None
    
    def decrypt_file(self, filepath, output_path=None, password=None):
        """Decrypt a log file"""
        try:
            key = self.load_key(password)
            fernet = Fernet(key)
            
            # Read encrypted file
            with open(filepath, 'rb') as f:
                encrypted = f.read()
            
            # Decrypt
            decrypted = fernet.decrypt(encrypted)
            
            # Determine output path
            if output_path is None:
                if filepath.endswith('.enc'):
                    output_path = filepath[:-4]
                else:
                    output_path = filepath + '.dec'
            
            # Write decrypted file
            with open(output_path, 'wb') as f:
                f.write(decrypted)
            
            print(f"[+] Decrypted: {filepath} -> {output_path}")
            print(f"    Decrypted size: {len(decrypted)} bytes")
            
            return output_path
            
        except Exception as e:
            print(f"[-] Decryption failed: {e}")
            return None
    
    def encrypt_directory(self, directory, pattern="*.log", password=None):
        """Encrypt all matching files in directory"""
        directory = Path(directory)
        encrypted_files = []
        
        for filepath in directory.rglob(pattern):
            if filepath.is_file() and not filepath.name.endswith('.enc'):
                result = self.encrypt_file(str(filepath), password=password)
                if result:
                    encrypted_files.append(result)
                    # Optionally delete original
                    # os.remove(filepath)
        
        print(f"\n[+] Encrypted {len(encrypted_files)} files")
        return encrypted_files
    
    def decrypt_directory(self, directory, pattern="*.enc", password=None):
        """Decrypt all encrypted files in directory"""
        directory = Path(directory)
        decrypted_files = []
        
        for filepath in directory.rglob(pattern):
            if filepath.is_file():
                result = self.decrypt_file(str(filepath), password=password)
                if result:
                    decrypted_files.append(result)
        
        print(f"\n[+] Decrypted {len(decrypted_files)} files")
        return decrypted_files

def main():
    import argparse
    
    parser = argparse.ArgumentParser(
        description='NullSec Log Encryption Utility',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Generate encryption key
  %(prog)s --generate-key

  # Encrypt a log file
  %(prog)s --encrypt /path/to/logfile.log

  # Decrypt a log file
  %(prog)s --decrypt /path/to/logfile.log.enc

  # Encrypt all logs in directory
  %(prog)s --encrypt-dir ~/nullsec/logs

  # Decrypt all encrypted logs
  %(prog)s --decrypt-dir ~/nullsec/logs
        """
    )
    
    parser.add_argument('--generate-key', action='store_true',
                        help='Generate new encryption key')
    parser.add_argument('--encrypt', metavar='FILE',
                        help='Encrypt a file')
    parser.add_argument('--decrypt', metavar='FILE',
                        help='Decrypt a file')
    parser.add_argument('--encrypt-dir', metavar='DIR',
                        help='Encrypt all log files in directory')
    parser.add_argument('--decrypt-dir', metavar='DIR',
                        help='Decrypt all encrypted files in directory')
    parser.add_argument('--output', '-o', metavar='FILE',
                        help='Output file path')
    parser.add_argument('--pattern', default='*.log',
                        help='File pattern for directory operations (default: *.log)')
    parser.add_argument('--key-file', metavar='FILE',
                        help='Custom key file location')
    
    args = parser.parse_args()
    
    if len(sys.argv) == 1:
        parser.print_help()
        sys.exit(1)
    
    try:
        encryptor = LogEncryption(key_file=args.key_file)
        
        if args.generate_key:
            encryptor.generate_key()
        
        elif args.encrypt:
            encryptor.encrypt_file(args.encrypt, args.output)
        
        elif args.decrypt:
            encryptor.decrypt_file(args.decrypt, args.output)
        
        elif args.encrypt_dir:
            encryptor.encrypt_directory(args.encrypt_dir, args.pattern)
        
        elif args.decrypt_dir:
            encryptor.decrypt_directory(args.decrypt_dir, '*.enc')
        
        else:
            parser.print_help()
    
    except KeyboardInterrupt:
        print("\n[!] Interrupted")
        sys.exit(1)
    except Exception as e:
        print(f"[!] Error: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()
