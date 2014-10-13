class ChecksumAuditLog < ActiveRecord::Base

  def ChecksumAuditLog.get_audit_log(pid, version_uuid)
    ChecksumAuditLog.find_or_create_by(:pid => pid, :version => version_uuid)
  end

  def ChecksumAuditLog.prune_history(pid)
    ## Check to see if there are previous passing logs that we can delete
    # we want to keep the first passing event after a failure, the most current passing event, 
    # and all failures so that this table doesn't grow too large
    # Simple way (a little naieve): if the last 2 were passing, delete the first one
    logs = GenericFile.find(pid).logs
    list = logs.limit(2)
    if list.size > 1 && (list[0].pass == 1) && (list[1].pass == 1)
      list[0].destroy
    end
  end
end
