class Api::V1::GltfModelsController < ApplicationController
  before_action :set_gltf_model, only: [:show, :update, :destroy]
  
  # GET /api/v1/gltf_models
  def index
    @models = GltfModel.all.order(:category, :name)
    render json: @models.as_json(
      only: [:id, :name, :category, :default_width, :default_height, :default_depth],
      methods: [:model_available?, :preview_available?]
    )
  end
  
  # GET /api/v1/gltf_models/:id
  def show
    render json: @gltf_model.as_json(
      methods: [:model_available?, :preview_available?, :display_dimensions, :default_volume, :default_footprint]
    )
  end
  
  # GET /api/v1/gltf_models/categories/:category
  def by_category
    @models = GltfModel.by_category(params[:category]).order(:name)
    render json: @models.as_json(
      only: [:id, :name, :default_width, :default_height, :default_depth],
      methods: [:model_available?, :preview_available?]
    )
  end
  
  # POST /api/v1/gltf_models
  def create
    @gltf_model = GltfModel.new(gltf_model_params)
    
    if @gltf_model.save
      render json: @gltf_model, status: :created
    else
      render json: { errors: @gltf_model.errors }, status: :unprocessable_entity
    end
  end
  
  # PATCH/PUT /api/v1/gltf_models/:id
  def update
    if @gltf_model.update(gltf_model_params)
      render json: @gltf_model
    else
      render json: { errors: @gltf_model.errors }, status: :unprocessable_entity
    end
  end
  
  # DELETE /api/v1/gltf_models/:id
  def destroy
    @gltf_model.destroy
    head :no_content
  end
  
  # GET /api/v1/gltf_models/:id/download
  def download
    if @gltf_model.model_available?
      redirect_to rails_blob_path(@gltf_model.model_file, disposition: "attachment")
    else
      render json: { error: 'Model file not available' }, status: :not_found
    end
  end
  
  # GET /api/v1/gltf_models/:id/preview
  def preview
    if @gltf_model.preview_available?
      redirect_to rails_blob_path(@gltf_model.preview_image, disposition: "inline")
    else
      render json: { error: 'Preview image not available' }, status: :not_found
    end
  end
  
  private
  
  def set_gltf_model
    @gltf_model = GltfModel.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'GLTF model not found' }, status: :not_found
  end
  
  def gltf_model_params
    params.require(:gltf_model).permit(
      :name, :category, :description, :default_width, :default_height, :default_depth,
      :model_file, :preview_image
    )
  end
end
