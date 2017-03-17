import RelationshipsTable from 'sufia/relationships/table'
import SaveWorkControl from 'sufia/save_work/save_work_control'
import AdminSetWidget from 'sufia/editor/admin_set_widget'

export default class {
  constructor(element) {
    this.element = element
    this.adminSetWidget = new AdminSetWidget(element.find('select[id$="_admin_set_id"]'))
    this.sharingTabElement = $('#tab-share')

    this.sharingTab()
    this.relationshipsTable()
    this.saveWorkControl()
    this.saveWorkFixed()
  }

  // Display the sharing tab if they select an admin set that permits sharing
  sharingTab() {
    if(this.adminSetWidget && !this.adminSetWidget.isEmpty()) {
      this.adminSetWidget.on('change', (data) => this.sharingTabVisiblity(data))
      this.sharingTabVisiblity(this.adminSetWidget.isSharing())
    }
  }

  sharingTabVisiblity(visible) {
      if (visible)
         this.sharingTabElement.removeClass('hidden')
      else
         this.sharingTabElement.addClass('hidden')
  }

  relationshipsTable() {
      new RelationshipsTable(this.element.find('table.relationships-ajax-enabled'))
  }

  saveWorkControl() {
      new SaveWorkControl(this.element.find("#form-progress"), this.adminSetWidget)
  }

  saveWorkFixed() {
      // Setting test to false to skip native and go right to polyfill
      FixedSticky.tests.sticky = false
      this.element.find('#savewidget').fixedsticky()
  }
}