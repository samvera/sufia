class Sufia::FindWorksSearchBuilder < Sufia::SearchBuilder
  include Sufia::MySearchBuilderBehavior
  include CurationConcerns::FilterByType

  def initialize(context)
    super(context)
    @id = context.params[:id]
  end

  #self.default_processor_chain += [:add_advanced_search_to_solr, :show_only_resources_deposited_by_current_user]
  self.default_processor_chain += [:show_only_resources_deposited_by_current_user]
  self.default_processor_chain += [:show_only_other_works, :show_only_works_not_child, :show_only_works_not_parent]

  def show_only_other_works(solr_parameters)
    solr_parameters[:fq] ||= []
    solr_parameters[:fq] += [
      "-" + ActiveFedora::SolrQueryBuilder.construct_query_for_ids([@id])
    ]
  end

  def show_only_works_not_child(solr_parameters)
    ids = begin
            ActiveFedora::SolrService
            .query("{!field f=id}#{@id}",fl: "member_ids_ssim")
            .flat_map { |x| x.fetch("member_ids_ssim", [])}
          end
    solr_parameters[:fq] ||= []
    solr_parameters[:fq]  += [
      "-" + ActiveFedora::SolrQueryBuilder.construct_query_for_ids([ids])
    ]
  end

  def show_only_works_not_parent(solr_parameters)
    solr_parameters[:fq] ||= []
    solr_parameters[:fq]  += [
      "-" + ActiveFedora::SolrQueryBuilder.construct_query(member_ids_ssim: @id)
    ]
  end

  def only_works?
    true
  end
end
