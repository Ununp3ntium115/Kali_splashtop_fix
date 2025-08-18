#!/usr/bin/env python3
import os
import struct
import tarfile
import io
from pathlib import Path

def extract_ar_archive(ar_path, output_dir):
    """Extract an ar archive (like .deb files)"""
    
    Path(output_dir).mkdir(parents=True, exist_ok=True)
    
    with open(ar_path, 'rb') as f:
        # Check ar signature
        signature = f.read(8)
        if signature != b'!<arch>\n':
            print(f"Not a valid ar archive: {signature}")
            return False
        
        while True:
            # Read file header (60 bytes)
            header = f.read(60)
            if len(header) < 60:
                break
                
            # Parse ar header format:
            # filename (16 bytes), timestamp (12), owner id (6), group id (6), 
            # mode (8), size (10), ending (2)
            filename = header[0:16].decode('ascii').strip()
            size_str = header[48:58].decode('ascii').strip()
            
            if not size_str:
                break
                
            size = int(size_str)
            
            # Read file data
            data = f.read(size)
            
            # Skip padding byte if size is odd
            if size % 2:
                f.read(1)
            
            # Save the file
            output_path = os.path.join(output_dir, filename)
            print(f"Extracting: {filename} ({size} bytes)")
            
            with open(output_path, 'wb') as out_file:
                out_file.write(data)
        
        return True

def extract_deb_contents(deb_path, output_dir):
    """Extract .deb package completely"""
    
    # First extract the ar archive
    ar_dir = os.path.join(output_dir, "ar_contents")
    if not extract_ar_archive(deb_path, ar_dir):
        return False
    
    # List what we extracted
    print("\nExtracted ar contents:")
    for item in os.listdir(ar_dir):
        print(f"  {item}")
    
    # Extract the data.tar.* file (contains actual files)
    data_tar = None
    control_tar = None
    
    for item in os.listdir(ar_dir):
        if item.startswith('data.tar'):
            data_tar = os.path.join(ar_dir, item)
        elif item.startswith('control.tar'):
            control_tar = os.path.join(ar_dir, item)
    
    # Extract data files
    if data_tar:
        data_dir = os.path.join(output_dir, "data")
        Path(data_dir).mkdir(parents=True, exist_ok=True)
        print(f"\nExtracting {data_tar} to {data_dir}")
        
        try:
            with tarfile.open(data_tar, 'r:*') as tar:
                tar.extractall(data_dir)
                print("Data files extracted successfully")
        except Exception as e:
            print(f"Error extracting data tar: {e}")
    
    # Extract control files
    if control_tar:
        control_dir = os.path.join(output_dir, "control")
        Path(control_dir).mkdir(parents=True, exist_ok=True)
        print(f"\nExtracting {control_tar} to {control_dir}")
        
        try:
            with tarfile.open(control_tar, 'r:*') as tar:
                tar.extractall(control_dir)
                print("Control files extracted successfully")
        except Exception as e:
            print(f"Error extracting control tar: {e}")
    
    return True

if __name__ == "__main__":
    deb_file = "Splashtop_Streamer_Ubuntu_amd64.deb"
    extract_dir = "extracted_deb"
    
    # Remove existing directory
    if os.path.exists(extract_dir):
        import shutil
        shutil.rmtree(extract_dir)
    
    if extract_deb_contents(deb_file, extract_dir):
        print(f"\n=== Successfully extracted {deb_file} ===")
        
        # Show directory structure
        print("\nDirectory structure:")
        for root, dirs, files in os.walk(extract_dir):
            level = root.replace(extract_dir, '').count(os.sep)
            indent = '  ' * level
            print(f"{indent}{os.path.basename(root)}/")
            subindent = '  ' * (level + 1)
            for file in files:
                file_path = os.path.join(root, file)
                size = os.path.getsize(file_path)
                print(f"{subindent}{file} ({size} bytes)")
    else:
        print("Failed to extract deb file")