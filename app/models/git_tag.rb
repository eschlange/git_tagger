module GitTagger
  # Tag holds all relevant information used to updated git tags of
  #   semantic versioning 2.0.0 - http://semver.org/
  class GitTag
    SEMANTIC_VERSION_UPDATE_TYPE_MAJOR = "major"
    SEMANTIC_VERSION_UPDATE_TYPE_MINOR = "minor"
    SEMANTIC_VERSION_UPDATE_TYPE_PATCH = "patch"

    attr_reader :semantic_version
    attr_reader :last_tag_date

    # Sets the current semantic version and the creation date of the last tag
    def initialize
      tag_list = `git tag | gsort -V`
      if tag_list && tag_list != ""
        @semantic_version = tag_list.split("\n").last
        # disabling cop, unable to break up system commands
        # rubocop:disable Metrics/LineLength, Style/StringLiterals
        @last_tag_date = `git log --tags --simplify-by-decoration --pretty="format:%ai" -n 1`
        @last_tag_date = DateTime.parse(@last_tag_date) + 1.second
        # rubocop:enable Metrics/LineLength, Style/StringLiterals
      else
        @semantic_version = "0.0.0"
        @last_tag_date = Date.today
      end
    end

    # Updates the tag semantic version based on the given update type
    def update(update_type)
      major = @semantic_version.split(".")[0].to_i
      minor = @semantic_version.split(".")[1].to_i
      patch = @semantic_version.split(".")[2].to_i

      case update_type
      when SEMANTIC_VERSION_UPDATE_TYPE_MAJOR
        major += 1
        minor = 0
        patch = 0
      when SEMANTIC_VERSION_UPDATE_TYPE_MINOR
        minor += 1
        patch = 0
      when SEMANTIC_VERSION_UPDATE_TYPE_PATCH
        patch += 1
      end
      @semantic_version = "#{ major }.#{ minor }.#{ patch }"
    end

    def create_and_push
      `git commit -m "Tag new release. (#{@semantic_version})\n* Updating changelog for latest tag.\n* Updating version to match latest tag."`
      `git push`
      `git tag #{ @semantic_version }`
      `git push --tags --follow-tags`
    end
  end
end