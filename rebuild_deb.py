#!/usr/bin/env python3
import os
import subprocess
import shutil
import tarfile
import time
from pathlib import Path

def create_tarball(source_dir, tar_path, compression='xz'):
    """Create a compressed tarball from a directory"""
    print(f"Creating {tar_path} from {source_dir}")
    
    mode_map = {
        'gz': 'w:gz',
        'xz': 'w:xz',
        'bz2': 'w:bz2'
    }
    
    with tarfile.open(tar_path, mode_map[compression]) as tar:
        # Change to the source directory to avoid including the full path
        old_cwd = os.getcwd()
        try:
            os.chdir(source_dir)
            for item in os.listdir('.'):
                print(f"  Adding: {item}")
                tar.add(item)
        finally:
            os.chdir(old_cwd)
    
    print(f"Created {tar_path} ({os.path.getsize(tar_path)} bytes)")

def create_ar_archive(output_path, files):
    """Create an ar archive (like .deb files)"""
    print(f"Creating ar archive: {output_path}")
    
    with open(output_path, 'wb') as ar_file:
        # Write ar signature
        ar_file.write(b'!<arch>\n')
        
        for file_path in files:
            filename = os.path.basename(file_path)
            file_size = os.path.getsize(file_path)
            
            # Create ar header (60 bytes total)
            header = bytearray(60)
            
            # filename (16 bytes, padded with spaces)
            filename_bytes = filename.encode('ascii')[:16]
            header[0:len(filename_bytes)] = filename_bytes
            for i in range(len(filename_bytes), 16):
                header[i] = ord(' ')
            
            # timestamp (12 bytes)
            timestamp = str(int(time.time())).encode('ascii')
            header[16:16+len(timestamp)] = timestamp
            for i in range(16+len(timestamp), 28):
                header[i] = ord(' ')
            
            # owner id (6 bytes)
            header[28:30] = b'0 '
            for i in range(30, 34):
                header[i] = ord(' ')
            
            # group id (6 bytes)
            header[34:36] = b'0 '
            for i in range(36, 40):
                header[i] = ord(' ')
            
            # mode (8 bytes)
            header[40:44] = b'644 '
            for i in range(44, 48):
                header[i] = ord(' ')
            
            # size (10 bytes)
            size_str = str(file_size).encode('ascii')
            header[48:48+len(size_str)] = size_str
            for i in range(48+len(size_str), 58):
                header[i] = ord(' ')
            
            # ending (2 bytes)
            header[58:60] = b'`\n'
            
            # Write header
            ar_file.write(header)
            
            # Write file content
            with open(file_path, 'rb') as f:
                shutil.copyfileobj(f, ar_file)
            
            # Add padding byte if size is odd
            if file_size % 2:
                ar_file.write(b'\n')
            
            print(f"  Added: {filename} ({file_size} bytes)")

def rebuild_deb_package(extracted_dir, output_deb):
    """Rebuild a .deb package from extracted contents"""
    
    # Paths
    ar_contents_dir = os.path.join(extracted_dir, "ar_contents")
    data_dir = os.path.join(extracted_dir, "data")
    control_dir = os.path.join(extracted_dir, "control")
    
    # Create temporary directory for rebuilding
    temp_dir = os.path.join(extracted_dir, "rebuild_temp")
    Path(temp_dir).mkdir(exist_ok=True)
    
    try:
        # 1. Copy debian-binary
        debian_binary_path = os.path.join(temp_dir, "debian-binary")
        original_debian_binary = os.path.join(ar_contents_dir, "debian-binary")
        if os.path.exists(original_debian_binary):
            shutil.copy2(original_debian_binary, debian_binary_path)
        else:
            # Create debian-binary if it doesn't exist
            with open(debian_binary_path, 'w') as f:
                f.write('2.0\n')
        
        # 2. Create control.tar.gz
        control_tar_path = os.path.join(temp_dir, "control.tar.gz")
        create_tarball(control_dir, control_tar_path, 'gz')
        
        # 3. Create data.tar.xz
        data_tar_path = os.path.join(temp_dir, "data.tar.xz")
        create_tarball(data_dir, data_tar_path, 'xz')
        
        # 4. Create the .deb file (ar archive)
        ar_files = [
            debian_binary_path,
            control_tar_path, 
            data_tar_path
        ]
        
        create_ar_archive(output_deb, ar_files)
        
        print(f"\n=== Successfully created {output_deb} ===")
        print(f"Size: {os.path.getsize(output_deb)} bytes")
        
        return True
        
    finally:
        # Cleanup temp directory
        if os.path.exists(temp_dir):
            shutil.rmtree(temp_dir)

if __name__ == "__main__":
    extracted_dir = "extracted_deb"
    output_deb = "Splashtop_Streamer_Kali_amd64.deb"
    
    if not os.path.exists(extracted_dir):
        print(f"Error: {extracted_dir} directory not found")
        exit(1)
    
    # Remove existing output file
    if os.path.exists(output_deb):
        os.remove(output_deb)
    
    if rebuild_deb_package(extracted_dir, output_deb):
        print(f"\nKali Linux compatible .deb package created: {output_deb}")
        print("\nKey changes made:")
        print("- Updated package version to 3.7.4.0-1kali1")
        print("- Modified dependencies for Kali Linux compatibility")
        print("- Added support for LightDM display manager")
        print("- Enhanced systemd service configuration")
        print("- Updated maintainer information")
    else:
        print("Failed to rebuild package")
        exit(1)