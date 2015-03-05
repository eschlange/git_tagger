module GitTagger
  # Represents a changelog for a project.
  class Changelog
    attr_reader :update_text

    # Sets the updated changelog text based on a semantic version and message
    def initialize(version, message)
      @update_text = "## #{ version } - " \
      "#{ DateTime.now.strftime('%F') }\n * #{ message }\n\n"
    end

    # Updated the changelog file with the new update text
    def update(project_type)
      @changelog_path = locate_changelog project_type
      new_changelog = "#{ @changelog_path }.new"

      if !File.exist?(@changelog_path)
        File.open(@changelog_path, "w") {}
      end

      File.open(new_changelog, "w") do |fo|
        fo.puts @update_text
        File.foreach(@changelog_path) do |li|
          fo.puts li
        end
      end

      File.rename(new_changelog, @changelog_path)
    end

    # utilizes system commands to commit the changelog locally
    def commit
      `git add "#{ @changelog_path }"`
      `git commit -m "Updating changelog for latest tag."`
    end

    private

    # locates and returns a changelog filepath based on project type
    def locate_changelog(project_type)
      case project_type
      when :rails_application
        File.expand_path(Rails.root.join "CHANGELOG.md")
      when :rails_gem
        File.expand_path(Rails.root.join "../../CHANGELOG.md")
      when :non_rails_gem
        File.join(File.dirname(File.expand_path(__FILE__)),
                  "../../CHANGELOG.md")
      else
        puts "no changelog file could be found to update"
        abort("aborting tagging process")
      end
    end
  end
end