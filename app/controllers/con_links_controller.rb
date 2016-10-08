class ConLinksController < ApplicationController
  before_action :authenticate_user!
  skip_before_action :authenticate_user!, only: [:new, :create, :show]
  
  def new
    @con_link = ConLink.new
  end
  
  def show
    if user_signed_in?
      user = current_user
    else
      user = User.anonymous      
    end
    @l = user.con_links.find(params[:id])
    @ra = @l.raw_extraction
    @resolved_names = JSON.parse(@ra.species)['resolvedNames'] rescue []
    @resolved_names = [] if !@resolved_names
    respond_to do |format|
      format.html
      format.js
    end
  end
  
  def create
    if user_signed_in?
      user = current_user
    else
      user = User.anonymous      
    end
    @con_link = user.con_links.build(con_link_params)
    if @con_link.save
      flash[:success] = "Processing!"
      job_id = ExtractionsWorker.perform_async(@con_link.id, "ConLink", user.id)
      redirect_to root_path(type: "cl", id: @con_link.id, jid: job_id)
    else
      flash[:error] = "Can not process link!"
      redirect_to new_con_link_path
    end
  end
  
  def update
    @con_link = current_user.con_links.find_by_id(params[:id])
    if @con_link.update_attributes(con_link_params)
      flash[:success] = "List name updated"
      redirect_to root_path
    else
      flash[:danger] = "Failed to update list name"
      redirect_to root_path
    end
  end
  
  def destroy
    cl = current_user.con_links.find(params[:id])
    if cl.nil?
      redirect_to root_path
    else 
      flash[:info] = "#{cl.name} is deleted"
      cl.destroy
      respond_to do |format|
        format.html { redirect_to root_path }
        format.js
      end
    end
  end
  
  private
    def con_link_params
      params.require(:con_link).permit(:uri, :name, :description)
    end
    
end
