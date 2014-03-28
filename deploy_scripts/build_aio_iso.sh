#!/bin/bash -xv

print_usage()
{
  echo "Usage: $0 <-o output_file> <-c crowbar.iso> <-b build_directory> <-p postinstall_src_dir>"
  echo "  *** Note: Please extract a copy of the Ubuntu12.04.4 disc to what will become the build_directory"
}

while [[ $1 ]]; do
  case $1 in
    # Where to output the completed ISO
    -o|--output)
      shift
      output_file=$1
      shift
      ;;
    # Crowbar ISO to pull in
    -c|--crowbar-iso)
      shift
      crowbar_iso=$1
      shift
      ;;
    # Build directory
    -b|--build-dir)
      shift
      build_dir=$1
      shift
      ;;
    # Location of postinstall stuff
    -p|--postinstall-src-dir)
      shift
      postinstall_src_dir=$1
      shift
      ;;
    # Help
    -h|--help)
      shift
      print_usage
      exit 0
      ;;
    *)
      echo "Unknown command line parameter $1"
      exit 1
      ;;
  esac
done

if [[ -z $output_file || -z $crowbar_iso || -z $build_dir || -z $postinstall_src_dir || ! -d $build_dir/.disc ]]; then
  print_usage
  exit 1
fi

echo "Building AIO iso: $output_file from crowbar iso: $crowbar_iso and postinstall files from: $postinstall_src_dir in build directory: $build_dir"

# Copy crowbar iso to build dir
cp $crowbar_iso $build_dir/postinstall/crowbar.iso || (echo "Failed to copy crowbar iso" && exit 1)

# Copy over postinstall stuff
cp -R $postinstall_src_dir $build_dir/postinstall/ || (echo "Failed to copy postinstall directory" && exit 1)

mkisofs -R -J -l -b isolinux/isolinux.bin -no-emul-boot -boot-load-size 4 -boot-info-table -iso-level 3 -o ${output_file} ${build_dir} || (echo "Failed to build AIO iso" && exit 1)

echo "Build finished successfully!"
exit 0
