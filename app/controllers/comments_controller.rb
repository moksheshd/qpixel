# Provides mainly web actions for using and making comments.
class CommentsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_comment, only: [:update, :destroy, :undelete]
  before_action :check_privilege, only: [:update, :destroy, :undelete]
  @@markdown_renderer = Redcarpet::Markdown.new(Redcarpet::Render::HTML.new(), extensions = {})

  # Supplies a pre-constructed Markdown renderer for use in rendering Markdown from views.
  def self.renderer
    @@markdown_renderer
  end

  # Authenticated web action. Creates a comment based on the data passed.
  def create
    @comment = Comment.new comment_params
    @comment.user = current_user
    post_type = @comment.post.post_type_id
    if @comment.save
      id = post_type == 1 ? @comment.post.id : @comment.post.parent_id
      @comment.post.user.create_notification("New comment on #{(post_type == 1 ? @comment.post.title : @comment.post.parent.title)}", "/questions/#{id}")

      match = @comment.content.match(/@(?<name>\S+) /)
      if match && match[:name]
        user = User.find_by_username(match[:name])
        user.create_notification("You were mentioned in a comment", "/questions/#{id}") if user
      end

      if post_type == 1
        redirect_to url_for(controller: :questions, action: :show, id: id)
      else
        redirect_to url_for(controller: :questions, action: :show, id: id)
      end
    else
      flash[:error] = "Comment failed to save."
      if post_type == 1
        redirect_to url_for(controller: :questions, action: :show, id: @comment.post.id)
      else
        redirect_to url_for(controller: :questions, action: :show, id: @comment.post.parent.id)
      end
    end
  end

  # Authenticated web action. Updates an existing comment with new data, based on the parameters passed to the request.
  def update
    post_type = @comment.post.post_type_id
    if @comment.update comment_params
      if post_type == 1
        redirect_to url_for(controller: :questions, action: :show, id: @comment.post.id)
      else
        redirect_to url_for(controller: :questions, action: :show, id: @comment.post.parent.id)
      end
    else
      flash[:error] = "Comment failed to update."
      if post_type == 1
        redirect_to url_for(controller: :questions, action: :show, id: @comment.post.id)
      else
        redirect_to url_for(controller: :questions, action: :show, id: @comment.post.parent.id)
      end
    end
  end

  # Authenticated web action. Deletes a comment by setting the <tt>deleted</tt> field to true.
  def destroy
    @comment.deleted = true
    post_type = @comment.post.post_type_id
    if @comment.save
      if post_type == 1
        redirect_to url_for(controller: :questions, action: :show, id: @comment.post.id)
      else
        redirect_to url_for(controller: :questions, action: :show, id: @comment.post.parent.id)
      end
    else
      flash[:error] = "Comment marked deleted, but not saved - status unknown."
      if post_type == 1
        redirect_to url_for(controller: :questions, action: :show, id: @comment.post.id)
      else
        redirect_to url_for(controller: :questions, action: :show, id: @comment.post.parent.id)
      end
    end
  end

  # Authenticated web action. Undeletes a comment by returning the <tt>deleted</tt> field to false.
  def undelete
    @comment.deleted = false
    post_type = @comment.post.post_type_id
    if @comment.save
      if post_type == 1
        redirect_to url_for(controller: :questions, action: :show, id: @comment.post.id)
      else
        redirect_to url_for(controller: :questions, action: :show, id: @comment.post.parent.id)
      end
    else
      flash[:error] = "Comment marked undeleted, but not saved - status unknown."
      if post_type == 1
        redirect_to url_for(controller: :questions, action: :show, id: @comment.post.id)
      else
        redirect_to url_for(controller: :questions, action: :show, id: @comment.post.parent.id)
      end
    end
  end

  private
    # Sanitizes parameters for use in creating or updating comments.
    def comment_params
      params.require(:comment).permit(:content, :post_type, :post_id)
    end

    # Finds the comment with the given ID and sets it to the <tt>@comment</tt> variable.
    def set_comment
      @comment = Comment.unscoped.find params[:id]
    end

    # Checks that the user trying to access the action has the required privilege - author or moderator/admin.
    def check_privilege
      unless current_user.is_moderator || current_user.is_admin || current_user == @comment.user
        render template: 'errors/forbidden', status: 401
      end
    end
end

# Provides a custom HTML sanitization interface to use for cleaning up the HTML in questions.
class CommentScrubber < Rails::Html::PermitScrubber
  # Sets up the scrubber instance with permissible tags and attributes.
  def initialize
    super
    self.tags = %w( a b i em strong strike del code )
    self.attributes = %w( href title )
  end

  # Defines which nodes should be skipped when sanitizing HTML.
  def skip_node?(node)
    node.text?
  end
end
