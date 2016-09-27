class ConFilesController < ApplicationController
  before_action :authenticate_user!
  
  def new
    @con_file = ConFile.new
  end
    
  def show
    @f = ConFile.find(params[:id])
    @ra = @f.raw_extraction
    if @ra.nil?
      respond_to do |format|
        format.js
      end
      return
    end
    @resolved_names = JSON.parse(@ra.species)['resolvedNames'] rescue []
    @resolved_names = [] if !@resolved_names
    respond_to do |format|
      format.html
      format.js
    end
  end
  
  def create
    @con_file = current_user.con_files.build(con_file_params)
    if @con_file.save
      flash[:success] = "Processing file!"
      job_id = ExtractionsWorker.perform_async(@con_file.id, "ConFile", current_user.id)
      redirect_to root_path
    else
      flash[:error] = "Can not process file!"
      redirect_to new_con_file_path
    end
  end
  
  def update
    @con_file = current_user.con_files.find_by_id(params[:id])
    if @con_file.update_attributes(con_file_params)
      flash[:success] = "List name updated"
      redirect_to root_path
    else
      flash[:danger] = "Failed to update list name"
      redirect_to root_path
    end
  end
  
  def destroy
    cf = current_user.con_files.find(params[:id])
    if cf.nil?
      redirect_to root_path
    else 
      cf.destroy
      respond_to do |format|
        format.html { redirect_to root_path }
        format.js
      end
    end
  end
  
  private
    def con_file_params
      params.fetch(:con_file, {}).permit(:document, :name, :description, :method)
    end
end
