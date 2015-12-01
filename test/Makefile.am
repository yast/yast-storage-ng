#
# Makefile.am for storage/test
#

TESTS = \
	disk_size_test.rb						\
	format_target_map_test.rb					\
	storage_snapper_configure_snapper_test.rb			\
	storage_get_disk_partition.rb					\
	storage_boot_on_raid1.rb					\
	partitions_test.rb						\
	include/partitioning_custom_part_check_generated_include_test.rb

# Disabled until the new libstorage is available:
#	storage_proposal_test.rb

TEST_EXTENSIONS = .rb
RB_LOG_COMPILER = rspec
VERBOSE = 1
EXTRA_DIST = $(TESTS)
