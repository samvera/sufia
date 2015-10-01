require 'spec_helper'

describe CurationConcerns::GenericFilesController do
  let(:user) { FactoryGirl.create(:user) }
  let(:file) { fixture_file_upload('files/image.png', 'image/png') }
  let(:parent) { FactoryGirl.create(:generic_work, edit_users: [user.user_key], visibility: Hydra::AccessControls::AccessRight::VISIBILITY_TEXT_VALUE_PUBLIC) }

  context 'when signed in' do
    before { sign_in user }

    describe '#create' do
      before do
        GenericFile.destroy_all
      end

      context 'on the happy path' do
        let(:date_today) { DateTime.now }

        before do
          allow(DateTime).to receive(:now).and_return(date_today)
        end

        it 'calls the actor to create metadata and content' do
          expect(controller.send(:actor)).to receive(:create_metadata).with(nil, parent.id, files: [file], title: ['test title'], visibility: 'restricted')
          expect(controller.send(:actor)).to receive(:create_content).with(file).and_return(true)
          xhr :post, :create, parent_id: parent,
                              generic_file: { files: [file],
                                              title: ['test title'],
                                              visibility: 'restricted' }
          expect(response).to be_success
          expect(flash[:error]).to be_nil
        end
      end

      context "on something that isn't a file" do
        # Note: This is a duplicate of coverage in generic_files_controller_json_spec.rb
        it 'renders error' do
          xhr :post, :create, parent_id: parent, generic_file: { files: ['hello'] },
                              permission: { group: { 'public' => 'read' } }, terms_of_service: '1'
          expect(response.status).to eq 400
          msg = JSON.parse(response.body)['message']
          expect(msg).to match(/no file for upload/i)
        end
      end

      context 'when the file has a virus' do
        it 'displays a flash error' do
          skip 'pending hydra-works#89'
          expect(CurationConcerns::GenericFileActor).to receive(:virus_check).with(file.path).and_raise(CurationConcerns::VirusFoundError.new('A virus was found'))
          xhr :post, :create, parent_id: parent, generic_file: { files: [file] },
                              permission: { group: { 'public' => 'read' } }, terms_of_service: '1'
          expect(flash[:error]).to include('A virus was found')
        end
      end

      context 'when solr is down' do
        before do
          allow(controller.send(:actor)).to receive(:create_metadata)
          allow(controller.send(:actor)).to receive(:create_content).with(file).and_raise(RSolr::Error::Http.new({}, {}))
        end

        it 'errors out of create after on continuous rsolr error' do
          xhr :post, :create, parent_id: parent, generic_file: { files: [file] },
                              permission: { group: { 'public' => 'read' } }, terms_of_service: '1'
          expect(response.body).to include('Error occurred while creating generic file.')
        end
      end
    end

    describe 'destroy' do
      let(:generic_file) do
        generic_file = GenericFile.create! do |gf|
          gf.apply_depositor_metadata(user)
        end
        parent.generic_files << generic_file
        generic_file
      end

      it 'deletes the file' do
        expect(GenericFile.find(generic_file.id)).to be_kind_of GenericFile
        delete :destroy, id: generic_file
        expect { GenericFile.find(generic_file.id) }.to raise_error Ldp::Gone
        expect(response).to redirect_to main_app.curation_concerns_generic_work_path(parent)
      end
    end

    describe 'update' do
      let!(:generic_file) do
        generic_file = GenericFile.new.tap do |gf|
          gf.apply_depositor_metadata(user)
          gf.visibility = Hydra::AccessControls::AccessRight::VISIBILITY_TEXT_VALUE_PRIVATE
          gf.save!
        end
        parent.generic_files << generic_file
        generic_file
      end

      after do
        generic_file.destroy
      end

      context 'updating metadata' do
        it 'is successful and update attributes' do
          post :update, id: generic_file, generic_file:
            { title: ['new_title'], tag: [''], permissions_attributes: [{ type: 'person', name: 'archivist1', access: 'edit' }] }
          expect(response).to redirect_to main_app.curation_concerns_generic_file_path(generic_file)
          expect(assigns[:generic_file].title).to eq(['new_title'])
        end

        it 'goes back to edit on an error' do
          allow_any_instance_of(GenericFile).to receive(:valid?).and_return(false)
          post :update, id: generic_file, generic_file:
            { title: ['new_title'], tag: [''], permissions_attributes: [{ type: 'person', name: 'archivist1', access: 'edit' }] }
          expect(response.status).to eq 422
          expect(response).to render_template('edit')
          expect(assigns[:generic_file]).to eq generic_file
        end

        it 'adds a new groups and users' do
          post :update, id: generic_file, generic_file:
            { title: ['new_title'], tag: [''], permissions_attributes: [{ type: 'group', name: 'group1', access: 'read' }, { type: 'person', name: 'user1', access: 'edit' }] }

          expect(assigns[:generic_file].read_groups).to eq ['group1']
          expect(assigns[:generic_file].edit_users).to include('user1')
        end

        it 'updates existing groups and users' do
          generic_file.read_groups = ['group3']
          generic_file.save! # TODO: slow , more than one save.
          post :update, id: generic_file, generic_file:
            { title: ['new_title'], tag: [''], permissions_attributes: [{ type: 'group', name: 'group3', access: 'edit' }] }
          expect(assigns[:generic_file].edit_groups).to eq ['group3']
        end

        context 'updating visibility' do
          it 'applies public' do
            new_visibility = Hydra::AccessControls::AccessRight::VISIBILITY_TEXT_VALUE_PUBLIC
            post :update, id: generic_file, generic_file: { visibility: new_visibility, embargo_release_date: '' }
            expect(generic_file.reload.visibility).to eq new_visibility
          end

          it 'applies embargo' do
            post :update, id: generic_file, generic_file: {
              visibility: 'embargo',
              visibility_during_embargo: 'restricted',
              embargo_release_date: '2099-09-05',
              visibility_after_embargo: 'open',
              visibility_during_lease: 'open',
              lease_expiration_date: '2099-09-05',
              visibility_after_lease: 'restricted'
            }
            generic_file.reload
            expect(generic_file).to be_under_embargo
            expect(generic_file).to_not be_active_lease
          end
        end
      end

      context 'updating file content' do
        it 'is successful' do
          expect(CharacterizeJob).to receive(:perform_later).with(generic_file.id, kind_of(String))
          post :update, id: generic_file, generic_file: { files: [file] }
          expect(response).to redirect_to main_app.curation_concerns_generic_file_path(generic_file)
          skip 'pending hydra-works#89'
          expect(generic_file.reload.label).to eq 'image.png'
        end
      end

      context 'restoring an old version' do
        before do
          # don't run characterization jobs
          allow(CharacterizeJob).to receive(:perform_later)
          # Create version 1
          Hydra::Works::AddFileToGenericFile.call(generic_file, File.open(fixture_file_path('small_file.txt')), :original_file)
          # Create version 2
          Hydra::Works::AddFileToGenericFile.call(generic_file, File.open(fixture_file_path('curation_concerns_generic_stub.txt')), :original_file)
        end

        # TODO: This test should move into the GenericFileActor spec and just ensure the actor is called.
        it 'is successful' do
          expect(generic_file.latest_content_version.label).to eq('version2')
          expect(generic_file.original_file.content).to eq("This is a test fixture for curation_concerns: <%= @id %>.\n")
          post :update, id: generic_file, revision: 'version1'
          expect(response).to redirect_to main_app.curation_concerns_generic_file_path(generic_file)
          reloaded = generic_file.reload.original_file
          expect(reloaded.versions.last.label).to eq 'version3'
          expect(reloaded.content).to eq "small\n"
          expect(reloaded.mime_type).to eq 'text/plain'
        end
      end
    end
  end

  context 'someone elses (public) files' do
    let(:creator) { create(:user, email: 'archivist1@example.com') }
    let(:public_generic_file) { create(:generic_file, user: creator, read_groups: ['public']) }
    before { sign_in user }

    describe '#edit' do
      it 'gives me the unauthorized page' do
        get :edit, id: public_generic_file
        expect(response.code).to eq '401'
        expect(response).to render_template(:unauthorized)
      end
    end

    describe '#show' do
      it 'allows access to the file' do
        get :show, id: public_generic_file
        expect(response).to be_success
      end
    end
  end

  context 'when not signed in' do
    let(:private_generic_file) { create(:generic_file) }
    let(:public_generic_file) { create(:generic_file, read_groups: ['public']) }

    describe '#edit' do
      it 'requires login' do
        get :edit, id: public_generic_file
        expect(response).to fail_redirect_and_flash(main_app.new_user_session_path, 'You are not authorized to access this page.')
      end
    end

    describe '#show' do
      it 'denies access to private files' do
        get :show, id: private_generic_file
        expect(response).to fail_redirect_and_flash(main_app.new_user_session_path, 'You are not authorized to access this page.')
      end

      it 'allows access to public files' do
        expect(controller).to receive(:additional_response_formats).with(ActionController::MimeResponds::Collector)
        get :show, id: public_generic_file
        expect(response).to be_success
      end
    end

    describe '#new' do
      it 'does not let the user submit' do
        get :new, parent_id: parent
        expect(response).to fail_redirect_and_flash(main_app.new_user_session_path, 'You are not authorized to access this page.')
      end
    end
  end
end