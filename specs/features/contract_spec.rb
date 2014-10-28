require 'spec_helper'

describe 'Contracts' do

  let(:user)    { create(:admin) }
  let(:child)   { create(:admin, parent_id: user.id) }

  let(:contract)       { create(:contract, user: user, plico: 'AGS24929300') }
  let(:child_contract) { create(:contract, user: child, plico: 'AGW27721235') }
  let(:other_contract) { create(:contract, user_id: 10_000, plico: 'AGW34063945') }

  let(:distributors)  { [create(:distributor, distributor_type: 'gas', code: '23452345234523'), create(:distributor, name: 'EDISON', distributor_type: 'power', code: 'IT001E'), create(:distributor, name: 'TESLA', distributor_type: 'power', code: 'IT002E')] }

  let(:stakeholder)   { create(:stakeholder, name: 'Tester Testowicz') }
  let(:home_customer) { create(:home_customer, tax_code: 'RMNDNC89R04F839C',
                        first_name: 'Foo', last_name: 'Bar') }

  let(:basic_supplier)  { create(:supplier) }
  let(:basic_pricelist) { create(:price_list) }

  let(:zip_code) { create(:zip_code) }

  before { login_as user }

  context "#index" do
    it 'should show all contracts' do
      contract && child_contract && other_contract # create contracts

      visit contracts_path

      within "tr#contract_#{contract.id}" do
        page.should have_link 'AGS24929300'
      end

      within "tr#contract_#{child_contract.id}" do
        page.should have_link 'AGW27721235'
      end

      page.should have_link    'AGW34063945'
      page.should have_content 'AGW34063945'
    end
  end

  context "#show" do
    it 'should show child contract' do
      contract = child_contract
      visit contract_path(contract)

      within "#contract-details" do
        page.should have_content 'AGW27721235'
        page.should have_link contract.user.name, href: user_path(contract.user)
      end
    end
  end


  context "#deleting" do
    it 'should be able to delete contract from index page', :js => true do
      c = contract
      visit contracts_path

      page.evaluate_script('window.confirm = function() { return true; }') # solo con selenium
      click_link "delete_#{c.id}"
      page.should have_no_content c.plico
    end
  end

  context "#create" do
    after { DatabaseCleaner.clean_with(:truncation) }

    it 'should create new contract with existing customer', js: true do
      home_customer # create customer
      distributors  # create distributors
      stakeholder

      visit new_contract_path

      within 'form#new_contract' do
        fill_in 'contract_plico',     with: 'AGV26083245'
        fill_in 'contract_signed_at', with: '13/03/2013'

        fill_in 'contract_start_date', with: '01/08/2013'
        fill_in 'contract_end_date',   with: '31/08/2013'
      end

      within 'form#new_contract' do
        fill_in_autocomplete 'customer_search', 'RMNDNC'
      end
      choose_autocomplete('Foo Bar')

      within 'form#new_contract' do
        fill_in_autocomplete('agent_search', stakeholder.name)
      end
      choose_autocomplete(stakeholder.full_name)

      within 'form#new_contract' do
        fill_in_autocomplete('consultant_search', stakeholder.name)
      end
      choose_autocomplete(stakeholder.full_name)


      within 'form#new_contract' do
        click_button 'save-contract'
      end

      wait_until do
        current_path != new_contract_path
      end

      contract = Contract.find_by_plico('AGV26083245')
      customer = Customer.find_by_tax_code('RMNDNC89R04F839C')

      contract.user.should == user # current_user
      contract.signed_at == '13/03/2013'.to_date
      contract.document_type == 'original'

      contract.customer.should == customer
      contract.agent.should == stakeholder
      contract.consultant.should == stakeholder

      current_path.should == contract_path(contract)
    end

    it 'should validate basic contract fields', js: true do
      visit new_contract_path

      click_button 'save-contract'

      wait_until do
        current_path != new_contract_path
      end

      within '#new_contract' do
        within '#contract_plico_input' do
          page.should have_content('essere lasciato in bianco')
        end

        within '#contract_customer_input' do
          page.should have_content('essere lasciato in bianco')
        end
      end
    end

    it 'should create new contract with Select option for supplier menu', js: true do
      zip = zip_code
      basic_pricelist

      home_customer = create(:home_customer, tax_code: 'RMNDNC89R04F839C',
                          first_name: 'Foo', last_name: 'Bar', zip_code: zip_code)
      distributors  # create distributors

      visit new_contract_path

      within 'form#new_contract' do
        fill_in 'contract_plico', with: 'AGV20121212'
        fill_in 'contract_start_date', with: '01/08/2013'
        fill_in 'contract_end_date',   with: '31/08/2013'
      end

      within 'form#new_contract' do
        fill_in_autocomplete('agent_search', stakeholder.name)
      end
      choose_autocomplete(stakeholder.full_name)

      within 'form#new_contract' do
        fill_in_autocomplete('consultant_search', stakeholder.name)
      end
      choose_autocomplete(stakeholder.full_name)

      # popup customer
      click_link "create_new_customer_popup"

      within '#new-customer-form' do
        fill_in 'customer_customer_code', with: '123456'
        page.select 'Business', from: 'customer_customer_type'
        page.select 'Ditta Individuale', from: 'customer_legal_type'
        fill_in 'customer_tax_code', with: 'LOIDNC72T05G698B'
        fill_in 'customer_tax_code_for_company', with: '12345678901'
        fill_in 'customer_business_name', with: 'Mario Selecto srl'
        fill_in 'customer_address', with: 'via le mani dal naso'
        page.select zip.comunes.first.province.short, from: 'customer_province_id'

        fill_in 'customer_contact_address', with: 'via tiburtina'
        page.select zip.comunes.first.province.short, from: 'customer_contact_province_id'

        fill_in_autocomplete('legal_representant_search', stakeholder.name)
      end

      choose_autocomplete(stakeholder.full_name)

      within '#new-customer-form' do
        click_button "save-customer";
      end

      page.has_field?('#customer_search', with: 'Mario Selecto srl')

      click_button 'save-contract'

      wait_until do
        current_path != new_contract_path
      end

      contract    = Contract.find_by_plico('AGV20121212')
      customer    = Customer.find_by_tax_code('LOIDNC72T05G698B')
      supplier    = Supplier.find_by_name('basic_supplier')

      contract.user.should        == user # current_user
      contract.customer.should    == customer
      contract.agent.should == stakeholder
      contract.consultant.should == stakeholder

      current_path.should == contract_path(contract)
    end

    it 'should create new contract with new supplier created with popup', js: true do
      zip = zip_code
      basic_supplier
      basic_pricelist

      home_customer = create(:home_customer, tax_code: 'RMNDNC89R04F839C',
                          first_name: 'Foo', last_name: 'Bar', zip_code: zip_code)
      distributors  # create distributors

      visit new_contract_path

      within 'form#new_contract' do
        fill_in 'contract_plico', with: 'AGV20121212'
        fill_in 'contract_start_date', with: '01/08/2013'
        fill_in 'contract_end_date',   with: '31/08/2013'
      end

      within 'form#new_contract' do
        fill_in_autocomplete('agent_search', stakeholder.name)
      end
      choose_autocomplete(stakeholder.full_name)

      within 'form#new_contract' do
        fill_in_autocomplete('consultant_search', stakeholder.name)
      end
      choose_autocomplete(stakeholder.full_name)


      # popup customer
      click_link "create_new_customer_popup"

      within '#new-customer-form' do

        fill_in 'customer_customer_code', with: '123456'
        page.select 'Business', from: 'customer_customer_type'
        page.select 'Ditta Individuale', from: 'customer_legal_type'
        fill_in 'customer_tax_code', with: 'LOIDNC72T05G698B'
        fill_in 'customer_tax_code_for_company', with: '12345678901'
        fill_in 'customer_business_name', with: 'test popSupplier'
        fill_in 'customer_address', with: 'via le mani dal naso'
        page.select zip.comunes.first.province.short, from: 'customer_province_id'

        fill_in 'customer_contact_address', with: 'via tiburtina'
        page.select zip.comunes.first.province.short, from: 'customer_contact_province_id'

        fill_in_autocomplete('legal_representant_search', stakeholder.name)
      end

      choose_autocomplete(stakeholder.full_name)

      within '#new-customer-form' do
        click_button "save-customer";
      end

      page.has_field?('#customer_search', with: 'test popSupplier')

      click_button 'save-contract'

      wait_until do
        current_path != new_contract_path
      end

      contract = Contract.find_by_plico('AGV20121212')
      customer = Customer.find_by_tax_code('LOIDNC72T05G698B')

      contract.user.should       == user # current_user
      contract.customer.should   == customer
      contract.agent.should      == stakeholder
      contract.consultant.should == stakeholder

      current_path.should == contract_path(contract)
    end

    it 'shows an error message when trying to create a new sale price list without a selected supplier', js: true do
      basic_supplier

      visit new_contract_path

      within 'form#new_contract' do
        click_link "new-sale-price-list-link"

        expect(page).to have_content('Devi prima selezionare un fornitore')

        page.select basic_supplier.name, from: 'supplier'

        expect(page).not_to have_content('Devi prima selezionare un fornitore')
      end
    end
  end


end
