#!/usr/bin/env python3
import os
import subprocess
import shutil
import tarfile
from pathlib import Path

def extract_deb(deb_path, extract_dir):
    """Extract a .deb package using available tools"""
    
    # Create extraction directory
    Path(extract_dir).mkdir(exist_ok=True)
    
    # Try to use ar command if available
    try:
        subprocess.run(['ar', '-x', deb_path], cwd=extract_dir, check=True)
        print("Successfully extracted using ar command")
        return True
    except (subprocess.CalledProcessError, FileNotFoundError):
        pass
    
    # Try to use dpkg-deb if available
    try:
        subprocess.run(['dpkg-deb', '-x', deb_path, extract_dir], check=True)
        subprocess.run(['dpkg-deb', '-e', deb_path, os.path.join(extract_dir, 'DEBIAN')], check=True)
        print("Successfully extracted using dpkg-deb")
        return True
    except (subprocess.CalledProcessError, FileNotFoundError):
        pass
    
    # Manual extraction - .deb files are ar archives
    try:
        # Read the deb file as binary
        with open(deb_path, 'rb') as f:
            data = f.read()
        
        # Look for the ar archive signature
        if data[:8] != b'!<arch>\n':
            print("Not a valid ar archive")
            return False
        
        print("Manual extraction not implemented yet - need proper ar parser")
        return False
        
    except Exception as e:
        print(f"Manual extraction failed: {e}")
        return False

if __name__ == "__main__":
    deb_file = "Splashtop_Streamer_Ubuntu_amd64.deb"
    extract_dir = "extracted_deb"
    
    if extract_deb(deb_file, extract_dir):
        print(f"Successfully extracted {deb_file} to {extract_dir}")
        
        # List contents
        for root, dirs, files in os.walk(extract_dir):
            level = root.replace(extract_dir, '').count(os.sep)
            indent = ' ' * 2 * level
            print(f"{indent}{os.path.basename(root)}/")
            subindent = ' ' * 2 * (level + 1)
            for file in files:
                print(f"{subindent}{file}")
    else:
        print("Failed to extract deb file")