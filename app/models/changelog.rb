module GitTagger
  class Changelog

    attr_reader :changelog_path
    attr_reader :update_text

    def initialize(version, message)
      @update_text = "## #{ version } - " \
      "#{ DateTime.now.strftime('%F') }\n * #{ message }\n\n"
    end

    def update(project_type)
      original_changelog = locate_changelog project_type
      new_changelog = "#{ original_changelog }.new"

      File.open(new_changelog, "w") do |fo|
        fo.puts @update_text
        File.foreach(original_changelog) do |li|
          fo.puts li
        end
      end
      File.rename(new_changelog, original_changelog)
    end

    private

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