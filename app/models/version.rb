module GitTagger
  # Represents a version file within a project.
  class Version
    # Sets the project name and filepath based on a project type
    def initialize(project_type)
      @project_name = find_project_name project_type
      @version_file_path = version_file_location project_type, @project_name
      @project_type = project_type
    end

    # locates and returns a project's name based on the project type
    def find_project_name(project_type)
      case project_type
      when :rails_application
        Rails.application.class.parent_name.underscore
      when :rails_gem
        engine_path = ""
        Find.find(File.expand_path(Rails.root.join("../../lib"))) do |path|
          engine_path = path if path =~ /.*\/engine\.rb$/
        end
        engine_text = File.read(engine_path)
        (engine_text.match(/^module \w*$/))[0].split(" ")[1].underscore
      when :non_rails_gem
        # TODO: Add logic to find gem name and apply to version_file path
        "git_tagger"
      else
        puts "FATAL: Unknown project type, unable to determine project name!"
        abort("aborting tagging process")
      end
    end

    # Update version file to match updated tag
    def update_version_file(semantic_version)
      version_text = File.read(@version_file_path)
      version_contents = version_text
                         .gsub(/  VERSION = "[0-9]+\.[0-9]+\.[0-9]+"/,
                               "  VERSION = \"#{ semantic_version }\"")
      File.open(@version_file_path, "w") { |file| file.puts version_contents }

      `git add "#{ @version_file_path }"`

      if :rails_gem == @project_type
        `(cd #{ File.expand_path(Rails.root) }; bundle install)`
        `git add "#{ File.expand_path(Rails.root.join("Gemfile.lock")) }"`
      end

      `git commit -m "Updating version for latest tag."`
    end

    # Locates the version file and returns its path
    # TODO: Add logic to create version file for project if non-existant.
    def version_file_location(project_type, project_name)
      case project_type
      when :rails_application
        File.expand_path(Rails.root.join "lib/" \
                       "#{ project_name }.rb")
      when :rails_gem
        File.expand_path(Rails.root.join "../../lib/" \
                       "#{ project_name }/version.rb")
      when :non_rails_gem
        # TODO: add logic to find version path for non rails gems
        File.expand_path("../../../lib/git_tagger/version.rb", __FILE__)
      else
        puts "FATAL: Unknown project type, unable to update gem version!"
        abort("aborting tagging process")
      end
    end
  end
end
