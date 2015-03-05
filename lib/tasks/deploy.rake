require "find"
require "io/console"
require_relative "../../app/models/changelog"
require_relative "../../app/models/git_tag"
require_relative "../../app/models/version"

namespace :deploy do
  # Constants
  PURPLE = "\e[0;35m"
  WHITE = "\e[1;37m"
  YELLOW = "\e[0;33m"
  BLUE = "\e[0;34m"
  RED = "\e[0;31m"
  DEFAULT_COLOR = "\e[0m"

  # Common textual components
  DIVIDER_PURPLE = "\n#{ PURPLE } ======================================" \
            "==========================\e[0m\n"
  DIVIDER_BLUE = "\n#{ BLUE } =================================" \
            "===============================\e[0m\n"
  LINE_BUFFER = ""

  desc "Master tagging task, run this for the full tagging process."
  task :tag do
    puts DIVIDER_PURPLE
    print "#{ PURPLE } *** #{ WHITE }Welcome to git_tagger"\
    "!#{ DEFAULT_COLOR } #{ PURPLE } ***#{ DEFAULT_COLOR }"
    puts DIVIDER_PURPLE

    # Abort tagging process if there are uncommitted changes or commits that
    #   have not been pushed to the master branch in the repository.
    # TODO: remove following line before pushing!
    # clean_working_directory_check

    # Get the latest tag or create a new tag if no tag exists.
    git_tag = GitTagger::GitTag.new
    project_type = find_project_type_by_gemfile_location

    retrieve_tag_type(git_tag)
    create_changelog(git_tag, project_type)
    update_version(git_tag, project_type)

    print DIVIDER_PURPLE
    puts "#{ WHITE } Pushing updates to changelog and version files (if applicable) ... #{DEFAULT_COLOR}"
    puts "#{ WHITE } Final step: Pushing changelog, version file, and new tag ...#{ DEFAULT_COLOR }"
    git_tag.create_and_push
    puts "#{ WHITE } *** Tag creation complete! *** #{ DEFAULT_COLOR }"
    print DIVIDER_PURPLE
  end

  def retrieve_tag_type(tag)
    puts LINE_BUFFER
    puts "#{ YELLOW } - MAJOR#{ DEFAULT_COLOR } version when you make"\
    " incompatible API changes."
    puts "#{ YELLOW } - MINOR#{ DEFAULT_COLOR } version when you add "\
    "functionality in a backwards-compatible manner"
    puts "#{ YELLOW } - PATCH#{ DEFAULT_COLOR } version when you make"\
    " backwards-compatible bug fixes."
    puts LINE_BUFFER

    puts "#{ RED } Type the letter indicating the tag update type "
    print " #{ DEFAULT_COLOR }#{ YELLOW }MAJOR(#{ DEFAULT_COLOR }#{ WHITE }"\
    "M#{ YELLOW }), #{ YELLOW }MINOR(#{ DEFAULT_COLOR }#{ WHITE }m#{ YELLOW }"\
    "), #{ YELLOW }PATCH(#{ DEFAULT_COLOR }#{ WHITE }p#{ YELLOW }), "\
    "#{ YELLOW }QUIT(#{ DEFAULT_COLOR }#{ WHITE }q#{ YELLOW }) (#{ WHITE }"\
    "M#{ YELLOW }/#{ WHITE }m#{ YELLOW }/#{ WHITE }p#{ YELLOW }/#{ WHITE }q"\
    "#{ YELLOW }): #{ DEFAULT_COLOR }"

    input = ""
    Kernel.loop do
      input = STDIN.getch
      break if !input || %(m p q M).include?(input)
    end
    puts input

    old_semantic_version = tag.semantic_version
    case input
    when "p"
      tag.update(GitTagger::GitTag::SEMANTIC_VERSION_UPDATE_TYPE_PATCH)
    when "m"
      tag.update(GitTagger::GitTag::SEMANTIC_VERSION_UPDATE_TYPE_MINOR)
    when "M"
      tag.update(GitTagger::GitTag::SEMANTIC_VERSION_UPDATE_TYPE_MAJOR)
    when "q"
      abort("Aborting tag procedure")
    end

    puts LINE_BUFFER
    puts " The current tag is: [#{ old_semantic_version }]"
    puts " Updating tag to be: [#{ tag.semantic_version }]"
    puts LINE_BUFFER

    if !(confirm " #{ YELLOW }Is this correct? (#{WHITE}y#{YELLOW}/#{WHITE}n"\
    "#{YELLOW}) ")
      abort("Aborting tag procedure")
    end
  end

  # Create a changelog entry, update version file and commit to master
  def create_changelog(tag, project_type)
    if confirm " Would you like to create and commit a changelog message " \
    "related to your new tag? (y/n) "
      puts LINE_BUFFER
      puts " The following commits were made since the last tag was created"
      puts DIVIDER_BLUE

      # disabling cop, unable to break up system commands
      # rubocop:disable Metrics/LineLength, Style/StringLiterals
      print `git log --since="#{ tag.last_tag_date }" --pretty=format:'%Cblue %ci %Creset-%Cred %an%Creset - %s'`
      # rubocop:enable Metrics/LineLength, Style/StringLiterals

      puts DIVIDER_BLUE
      puts " #{ YELLOW }Enter a brief changelog message to describe the " \
      "updates since the last tag was created, then press [#{WHITE}ENTER" \
      "#{YELLOW}]#{DEFAULT_COLOR}"
      print "  * "
      changelog_message = STDIN.gets.strip
      puts LINE_BUFFER

      changelog = GitTagger::Changelog
                  .new(tag.semantic_version, changelog_message)
      puts "#{ YELLOW } The following will be prefixed to the CHANGELOG.md " \
      "file #{DEFAULT_COLOR}"
      puts LINE_BUFFER
      puts changelog.update_text

      if confirm "#{ YELLOW } Are you sure that you would like to commit " \
      "this change to origin/master before creating the new tag? (#{WHITE}y" \
      "#{YELLOW}/#{WHITE}n#{YELLOW})#{DEFAULT_COLOR} "
        changelog.update(project_type)
        changelog.commit
      else
        abort("Aborting tagging process.")
      end
    end
  end

  def confirm(question)
    print question
    confirmation = ""
    Kernel.loop do
      confirmation = STDIN.getch
      break if !confirmation || %(y n).include?(confirmation)
    end

    puts confirmation
    puts DIVIDER_PURPLE
    "y" == confirmation
  end

  # Determine location of gemfile and return project type
  def find_project_type_by_gemfile_location
    # If tagging an application or Gem that uses Rails
    if defined? Rails
      if File.file?(File.expand_path(Rails.root.join "Gemfile"))
        puts "-- determined that project type is a Rails application --"
        return :rails_application
      end
      if File.file?(File.expand_path(Rails.root.join "../../Gemfile"))
        puts "-- determined that project type is a Rails Gem --"
        return :rails_gem
      end
    else
      if File.file?(File.join(File.dirname(File.expand_path(__FILE__)),
                              "../../Gemfile"))
        puts "-- determined that project type is a Gem without Rails --"
        return :non_rails_gem
      end
    end
    puts "FATAL: unable to determine project type based on Gemfile location!"
    abort("aborting tagging process")
  end

  def update_version(tag, project_type)
    if confirm "#{ YELLOW } Would you like to update the project " \
      "version? (#{WHITE}y" \
      "#{YELLOW}/#{WHITE}n#{YELLOW})#{DEFAULT_COLOR} "
      version = GitTagger::Version.new(project_type)
      version.update_version_file(tag.semantic_version)
      puts "version file update complete!"
    end

  end

  # disabling cop, unable to break up system commands
  # rubocop:disable Metrics/LineLength, Style/StringLiterals
  def clean_working_directory_check
    commit_count_check = `git status`
    if (!(commit_count_check.include? "Your branch is up-to-date with 'origin/master'.") &&
        !(commit_count_check.include? "nothing to commit, working directory clean")) ||
       (commit_count_check.include? "Changes not staged for commit:")
      abort("ABORTING... please commit and push any local changes before atte"\
      "mpting to create a new tag")
    end
  end
  # rubocop:enable Metrics/LineLength, Style/StringLiterals
end
