require 'json'

class Report
  attr_accessor :id, :state, :line_count, :fault_code, :fault_reason
  def initialize(r)
    self.id = r[:id]
    self.state = r[:state]
    self.line_count = r[:line_count]
  end
  
  def refresh
    result = plsql.select(:first, "select state, line_count, fault_code from rp_reports where id = #{self.id}")
    self.state = result[:state]
    self.line_count = result[:line_count]
    self.fault_code = result[:fault_code]
    self.fault_reason = result[:fault_reason]
    self
  end
  
  def completed?
    self.state == 'COMPLETED'
  end

end

class ReportClrk
  def self.setup(args)
    args.merge!({
        id: plsql.rp_available_reports_seq.nextval,
        name: 'TestReport',
        dsn: 'REMITTANCE',
        created_at: Date.today,
        updated_at: Date.today,
        batch_size: 50,
        mime_type: 'text/plain',
        normalize_space: 'Y', 
        money_format: '########0.00'
      })
      
      args[:params_cnt] = 1
      args[:param1] = JSON.generate(param1_name: 'pi_param1', param1_type: 'number')
      
      if ['N','C'].include?(args[:header_kind])
        args[:db_unit] ||= 'pk_qg_test_rp_service.test_no_or_column_header'
      else
        args[:db_unit] ||= 'pk_qg_test_rp_service.test_data_header'
      end

      if args[:msg_model] == 'Y'
        if args[:header_kind] == 'D'
          args[:msg_model] = '{http://www.quantiguous.com/clrk/report}:data_header'
        elsif args[:header_kind] == 'C'
          args[:msg_model] = '{http://www.quantiguous.com/clrk/report}:fixed_header'
        else
          args[:msg_model] = '{http://www.quantiguous.com/clrk/report}:no_header'
        end
      end

    plsql.rp_available_reports.delete(args[:name])
    plsql.rp_available_reports.insert(args)
    
    plsql.commit
  end
  
  def self.get_param(params, i)
    return nil if params.nil?
    return nil if params.length < i 
    return {pri_data_type: 'text', pri_text_value: params[i], pri_date_value: nil, pri_number_value: nil} if params[i].is_a?(String)
    return {pri_data_type: 'date', pri_text_value: nil, pri_date_value: params[i], pri_number_value: nil} if params[i].is_a?(Date)
    return {pri_data_type: 'number', pri_text_value: nil, pri_date_value: nil, pri_number_value: params[i]} if params[i].is_a?(Integer)
  end
  
  def self.schedule_report(name, params = nil, run_at = nil, file_name = nil)

    plsql_result = plsql.pk_qg_rp_xface.schedule_report(
    pi_ar_name: name,
    pi_param1: get_param(params, 0),
    pi_param2: get_param(params, 1),
    pi_param3: get_param(params, 2),
    pi_param4: get_param(params, 3),
    pi_param5: get_param(params, 4),
    pi_run_at: run_at,
    pi_file_name: file_name,
    po_fault_code: nil,
    po_fault_reason: nil
    )
    
    plsql.commit
    
    rp_report_id = plsql_result[0]
    fault_code = plsql_result[1][:po_fault_code]
    fault_reason = plsql_result[1][:po_fault_reason]
    
    return {fault_code: fault_code, fault_reason: fault_reason} unless fault_code.nil?
    
    ReportClrk.get_report(rp_report_id)
  end
  
  def self.get_report(rp_report_id, x = nil)
    ::Report.new(plsql.select(:first, "select * from rp_reports where id = #{rp_report_id}"))
  end

end

describe 'ReportClrk' do

  context 'for an available report' do
    
    ['csv', 'plain'].each do |file|
      context "with file type #{file}" do
        ['N','C','D'].each do |header|
          context "and header kind #{header}" do
            [0,10,60].each do |row_count|
              context "and row_count #{row_count}" do
                context 'without message model' do
                  ar = {file_ext: file, header_kind: header}

                  before(:all) do
                    ReportClrk.setup(ar)
                  end
                  it "should #{row_count == 0 ? 'not' : '' } generate a report" do
                    r = ReportClrk.schedule_report('TestReport', [row_count])
                    wait_for{r.refresh}.to be_completed
                    expect(r.refresh.line_count).to eq(row_count)
                  end
                end

                context 'with message model' do
                  ar = {file_ext: file, header_kind: header, msg_model: 'Y'}

                  before(:all) do
                    ReportClrk.setup(ar)
                  end
                  it "should #{row_count == 0 ? 'not' : '' }generate a report" do
                    r = ReportClrk.schedule_report('TestReport', [row_count])
                    wait_for{r.refresh}.to be_completed
                    expect(r.refresh.line_count).to eq(row_count)
                  end
                end
              end
            end
          end
        end
      end
    end
    
    #FAILURE CASES
    context 'with escape character same as delimiter' do
      ar = {file_ext: 'csv', header_kind: 'C', escape_character: ',', delimiter: ','}

      before(:all) do
        ReportClrk.setup(ar)
      end

      it 'should fail' do
        r = ReportClrk.schedule_report('TestReport', [10])
        wait_for{r.refresh.fault_code}.not_to be_nil
      end
    end
    
    context 'with a non-existing message model name' do
      ar = {file_ext: 'csv', header_kind: 'C', msg_model: '{http://www.quantiguous.com/clrk/report}:abc'}

      before(:all) do
        ReportClrk.setup(ar)
      end

      it 'should fail' do
        r = ReportClrk.schedule_report('TestReport', [10])
        wait_for{r.refresh.fault_code}.not_to be_nil
      end
    end
    
    context 'with message model serialization failure (mismatch in column name)' do
      ar = {file_ext: 'csv', header_kind: 'D', msg_model: 'Y', db_unit: 'pk_qg_test_rp_service.test_header_failure'}

      before(:all) do
        ReportClrk.setup(ar)
      end

      it 'should fail' do
        r = ReportClrk.schedule_report('TestReport', [10])
        wait_for{r.refresh.fault_code}.not_to be_nil
      end
    end

  end

end
