require "yast"
require "storage/clients/proposal_demo"

if Process::UID.eid != 0
  STDERR.puts("This requires root permissions, otherwise hardware probing will fail.")
  STDERR.puts("Start this with sudo")
end
Yast::Storage::ProposalDemoClient.new(true).run
