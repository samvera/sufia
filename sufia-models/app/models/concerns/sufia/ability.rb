module Sufia
  module Ability
    extend ActiveSupport::Concern

    included do
      self.ability_logic += [:sufia_abilities]
    end

    def sufia_abilities
      generic_file_abilities
      featured_work_abilities
      editor_abilities
      stats_abilities
      proxy_deposit_abilities
      single_use_links_abilities
    end

    def proxy_deposit_abilities
      can :transfer, String do |id|
        depositor_for_document(id) == current_user.user_key
      end
      can :create, ProxyDepositRequest if user_groups.include? 'registered'
      can :accept, ProxyDepositRequest, receiving_user_id: current_user.id, status: 'pending'
      can :reject, ProxyDepositRequest, receiving_user_id: current_user.id, status: 'pending'
      # a user who sent a proxy deposit request can cancel it if it's pending.
      can :destroy, ProxyDepositRequest, sending_user_id: current_user.id, status: 'pending'
      can :edit, ::User, id: current_user.id
    end

    def featured_work_abilities
      can [:create, :destroy, :update], FeaturedWork if user_groups.include? 'admin'
    end

    def generic_file_abilities
      can :create, [GenericFile, Collection] if user_groups.include? 'registered'
    end

    def editor_abilities
      if user_groups.include? 'admin'
        can :create, TinymceAsset
        can [:create, :update], ContentBlock
      end
    end

    def stats_abilities
      alias_action :stats, to: :read
    end

    def single_use_links_abilities
      can :read, SingleUseLink 
    end


    private

    def depositor_for_document(document_id)
      ::GenericFile.load_instance_from_solr(document_id).depositor
    end

  end
end
