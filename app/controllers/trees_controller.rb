class TreesController < ApplicationController
  before_action :authenticate_user!
  
  def new
    ra = RawExtraction.find(params[:ra])
    if ra.contributable.user == current_user
      @tree = current_user.trees.build(raw_extraction_id: params[:ra])
      @resolved_names = JSON.parse ra.species
    end
  end
  
  def create
    params["tree"]["chosen_species"] = params["tree"]["chosen_species"].to_json  
    @tree = current_user.trees.build(tree_params)
    if @tree.raw_extraction.user != current_user
      redirect_to root_path
    end
    if @tree.save
      flash[:success] = "Tree is being constructed! We will inform you when your tree is ready"
      job_id = TreesWorker.perform_async(@tree.id)
      @tree.update_attributes( bg_job: job_id, status: "constructing")
      redirect_to trees_path
    else
      render 'static_pages/home'
    end
  end
  
  def show
    @tree = Tree.find_by(id: params[:id])
    if @tree.nil? 
      redirect_to root_url
    elsif @tree.status != "completed"
      flash[:danger] = "Tree is not ready to view"
      redirect_to trees_path
    else
      if !@tree.public
        if @tree.user != current_user
          redirect_to root_url
        end
      end
    end
  end
  
  def index
    @con_link_jobs        = current_user.con_links
    @con_file_jobs        = current_user.con_files
    @con_taxon_jobs       = current_user.con_taxons
    @selection_taxon_jobs = current_user.selection_taxons
    @subset_taxon_jobs    = current_user.subset_taxons
    res = Req.get(APP_CONFIG["sv_getuserlist"]["url"] + current_user.id.to_s)
    @prebuilt_jobs = res ? JSON.parse(res)["lists"] : []
    @prebuilt_jobs_failed = current_user.uploaded_lists.where(status: false)
    @processing = current_user.trees.select { |t| t.status != "completed" }.map { |t| t.id }
  end
  
  def explore
    @trees = Tree.where(public: true).paginate(:page => params[:page])
  end
  
  def edit
    @tree = current_user.trees.find_by_id(params[:id])
    @resolved_names = JSON.parse @tree.raw_extraction.species
  end
  
  def update
    @tree = current_user.trees.find_by_id(params[:id])
    params["tree"]["chosen_species"] = params["tree"]["chosen_species"].to_json  
    if @tree.update_attributes(tree_params)
      flash[:success] = "Tree ##{params[:id]} is under constructed. We will notify you when it is ready"
      job_id = TreesWorker.perform_async(@tree.id)
      @tree.update_attributes( bg_job: job_id, status: "constructing")
      redirect_to trees_path
    else
      render 'edit'
    end
  end
  
  def update_image
    @tree = current_user.trees.find_by_id(params[:id])
    if @tree.update_attributes(tree_params)
      respond_to do |format|
        format.html { redirect_to tree_path(params[:id]) }
        format.js { render 'update_image.js.erb'}
      end
    else
      flash[:danger] = "Cannot save tree image"
      redirect_to tree_path(params[:id])
    end
  end
  
  def public
    @tree = current_user.trees.find_by_id(params[:id])
    if @tree.update_attributes(tree_params)
      respond_to do |format|
        format.html { redirect_to tree_path(params[:id]) }
        format.js { render 'public.js.erb'}
      end
    end
  end
  
  def destroy
    tree = Tree.find(params[:id])
    if tree.nil?
      redirect_to root_path
    else 
      tree.destroy
      respond_to do |format|
        format.html { redirect_to trees_path }
        format.js
      end
    end
  end
  
  def search
    @trees = Tree.search do
      all do 
        fulltext params[:search]
        with(:public, true)
        paginate :page => params[:page], :per_page => 9
      end
    end.results
    render 'explore'
  end
  
  private
    def tree_params
      params.require(:tree).permit(:phylo_source_id, :branch_length, 
                                   :images_from_EOL, :image, :public, 
                                   :raw_extraction_id, :chosen_species,
                                   :description)
    end
end
