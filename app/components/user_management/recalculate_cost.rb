module UserManagement
  class RecalculateCost
    def candidates
      Db::Profile.includes(:payment).where(accepted: false, payments: { state: 'unpaid' })
    end

    def all
      candidates.each do |profile|
        ::UserManagement::Workers::ProfileRecalculateCostWorker.perform_async(profile.id)
      end
    end
  end
end
