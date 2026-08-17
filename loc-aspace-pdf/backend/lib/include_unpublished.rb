module IncludeUnpublished
  def include_unpublished!
    @include_unpublished = true
  end

  def include_unpublished?
    @include_unpublished ||= false
    @include_unpublished
  end
end
