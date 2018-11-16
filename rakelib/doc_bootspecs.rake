# Copyright (c) [2016] SUSE LLC
#
# All Rights Reserved.
#
# This program is free software; you can redistribute it and/or modify it
# under the terms of version 2 of the GNU General Public License as published
# by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
# more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, contact SUSE LLC.
#
# To contact SUSE LLC about this file by physical or electronic mail, you may
# find current contact information at www.suse.com.

namespace :doc do
  desc "Build boot requirements spec."
  task :bootspecs do
    files = Dir["**/test/y2storage/boot_requirements_checker_*_test.rb"].sort
    sh "PARALLEL_TESTS=0 rspec" \
      " --require ./src/tools/md_formatter.rb" \
      " --format MdFormatter" \
      " --out doc/boot-requirements.md" \
      " '#{files.join("' '")}'" unless files.empty?
  end
end
