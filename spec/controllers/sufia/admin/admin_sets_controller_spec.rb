require 'spec_helper'

describe Sufia::Admin::AdminSetsController do
  let(:user) { create(:user) }

  context "a non admin" do
    describe "#index" do
      it 'is unauthorized' do
        get :index
        expect(response).to be_redirect
      end
    end

    describe "#new" do
      let!(:admin_set) { create(:admin_set) }

      it 'is unauthorized' do
        get :new
        expect(response).to be_redirect
      end
    end

    describe "#show" do
      context "a public admin set" do
        # Even though the user can view this admin set, the should not be able to view
        # it on the admin page.
        let(:admin_set) { create(:admin_set, :public) }
        it 'is unauthorized' do
          get :show, params: { id: admin_set }
          expect(response).to be_redirect
        end
      end
    end
  end

  context "as an admin" do
    before do
      sign_in user
      allow(controller).to receive(:authorize!).and_return(true)
    end

    describe "#index" do
      it 'allows an authorized user to view the page' do
        get :index
        expect(response).to be_success
        expect(assigns[:admin_sets]).to be_kind_of Array
      end
    end

    describe "#new" do
      it 'allows an authorized user to view the page' do
        get :new
        expect(response).to be_success
      end
    end

    describe "#create" do
      let(:service) { instance_double(Sufia::AdminSetCreateService) }
      before do
        allow(Sufia::AdminSetCreateService).to receive(:new)
          .with(an_instance_of(AdminSet), user, anything)
          .and_return(service)
      end

      context "when it's successful" do
        it 'creates file sets' do
          expect(service).to receive(:create).and_return(true)
          post :create, params: { admin_set: { title: 'Test title',
                                               description: 'test description',
                                               workflow_name: 'default' } }
          expect(response).to be_redirect
        end
      end

      context "when it fails" do
        it 'shows the new form' do
          expect(service).to receive(:create).and_return(false)
          post :create, params: { admin_set: { title: 'Test title',
                                               description: 'test description' } }
          expect(response).to render_template 'new'
        end
      end
    end

    describe "#show" do
      context "when it's successful" do
        let(:admin_set) { create(:admin_set, edit_users: [user]) }
        before do
          create(:work, :public, admin_set: admin_set)
        end

        it 'defines a presenter' do
          get :show, params: { id: admin_set }
          expect(response).to be_success
          expect(assigns[:presenter]).to be_kind_of Sufia::AdminSetPresenter
          expect(assigns[:presenter].id).to eq admin_set.id
        end
      end
    end

    describe "#edit" do
      let(:admin_set) { create(:admin_set, edit_users: [user]) }
      it 'defines a form' do
        get :edit, params: { id: admin_set }
        expect(response).to be_success
        expect(assigns[:form]).to be_kind_of Sufia::Forms::AdminSetForm
      end
    end

    describe "#update" do
      let(:admin_set) { create(:admin_set, edit_users: [user]) }
      let(:permission_template) { create(:permission_template, admin_set_id: admin_set.id, workflow_name: workflow_name) }
      let(:workflow_name) { 'one_step_mediated_deposit' }
      it 'updates a record' do
        # Prevent a save which causes Fedora to complain it doesn't know the referenced node.
        expect_any_instance_of(AdminSet).to receive(:save).and_return(true)
        patch :update, params: { id: admin_set,
                                 admin_set: { title: "Improved title", thumbnail_id: "mw22v559x", workflow_name: workflow_name } }
        expect(response).to be_redirect
        expect(assigns[:admin_set].title).to eq ['Improved title']
        expect(assigns[:admin_set].thumbnail_id).to eq 'mw22v559x'
        expect(permission_template.workflow_name).to eq workflow_name
      end
    end

    describe "#destroy" do
      let(:admin_set) { create(:admin_set, edit_users: [user]) }

      context "with empty admin set" do
        it "deletes the admin set" do
          delete :destroy, params: { id: admin_set }
          expect(response).to have_http_status(:found)
          expect(response).to redirect_to(Sufia::Engine.routes.url_helpers.admin_admin_sets_path)
          expect(flash[:notice]).to eq "Administrative set successfully deleted"
          expect(AdminSet.exists?(admin_set.id)).to be false
        end
      end
      context "with a non-empty admin set" do
        let(:work) { create(:generic_work, user: user) }
        before do
          admin_set.members << work
          admin_set.reload
        end
        it "doesn't delete the admin set (or work)" do
          delete :destroy, params: { id: admin_set }
          expect(response).to have_http_status(:found)
          expect(response).to redirect_to(Sufia::Engine.routes.url_helpers.admin_admin_set_path(admin_set))
          expect(flash[:alert]).to eq "Administrative set cannot be deleted as it is not empty"
          expect(AdminSet.exists?(admin_set.id)).to be true
          expect(GenericWork.exists?(work.id)).to be true
        end
      end

      context "with the default admin set" do
        let(:admin_set) { create(:admin_set, edit_users: [user], id: AdminSet::DEFAULT_ID) }
        it "doesn't delete the admin set" do
          delete :destroy, params: { id: admin_set }
          expect(response).to have_http_status(:found)
          expect(response).to redirect_to(Sufia::Engine.routes.url_helpers.admin_admin_set_path(admin_set))
          expect(flash[:alert]).to eq "Administrative set cannot be deleted as it is the default set"
          expect(AdminSet.exists?(admin_set.id)).to be true
        end
      end
    end
  end
end
