# Copyright (c) 2014 SUSE LLC.
#  All Rights Reserved.

#  This program is free software; you can redistribute it and/or
#  modify it under the terms of version 2 or 3 of the GNU General
#  Public License as published by the Free Software Foundation.

#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.   See the
#  GNU General Public License for more details.

#  You should have received a copy of the GNU General Public License
#  along with this program; if not, contact SUSE LLC.

#  To contact SUSE about this file by physical or electronic mail,
#  you may find current contact information at www.suse.com

require "yast/rake"

# Checking for bug/fate numbers in the changelog does not make sense at this
# stage of the development
Rake::Task["package"].prerequisites.delete("check:changelog")

Yast::Tasks.configuration do |conf|
  conf.skip_license_check << /.*/
  # TODO: improve it, at least do not get worse
  # TODO: remove condition when new packaging tasks are accepted to factory
  conf.documentation_minimal = 79 if conf.respond_to?(:documentation_minimal=)
end
