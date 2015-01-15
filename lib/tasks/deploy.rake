require "io/console"

namespace :deploy do
  # Project types
  RAILS_APPLICATION = "rails_application"
  RAILS_GEM = "rails_gem"
  NON_RAILS_GEM = "non_rails_gem"
  GIT_TRIGGER_GEM = "git_trigger_gem"

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

  # Global variables
  current_tag = ""
  new_tag = ""
  current_tag_date = ""
  current_major = 0
  current_minor = 0
  current_patch = 0
  project_type = ""

  desc "Master tagging task, run this for the full tagging process."
  task :tag do

    puts DIVIDER_PURPLE
    print "#{ PURPLE } *** #{ WHITE }Welcome to git_tagger"\
    "!#{ DEFAULT_COLOR } #{ PURPLE } ***#{ DEFAULT_COLOR }"
    puts DIVIDER_PURPLE

    # Abort tagging process if there are uncommitted changes or commits that
    #   have not been pushed to the master branch in the repository.
    commit_count_check = `git status`
    if !(commit_count_check.include? "Your branch is up-to-date with 'origin/master'.") &&
       !(commit_count_check.include? "nothing to commit, working directory clean")
      abort("ABORTING... please commit and push any local changes before attempting to create a new tag")
    end

    # Get the latest tag or create a new tag if no tag exists.
    tag_list = `git tag | gsort -V`
    if tag_list
      current_tag = tag_list.split("\n").last
      current_tag_date = `git log --tags --simplify-by-decoration --pretty="format:%ai" -n 1`
    else
      current_tag = "0.0.0"
      current_tag_date = "2015-01-01 00:00:00 -0600"
    end

    current_major = current_tag.split(".")[0].to_i
    current_minor = current_tag.split(".")[1].to_i
    current_patch = current_tag.split(".")[2].to_i

    Rake::Task["deploy:retrieve_tag_type"].invoke
    Rake::Task["deploy:create_change_log"].invoke
    Rake::Task["deploy:create_and_push_tag"].invoke
  end

  desc "Choose the type of update."
  task :retrieve_tag_type do
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

    case input
    when "p"
      current_patch += 1
    when "m"
      current_minor += 1
      current_patch = 0
    when "M"
      current_major += 1
      current_minor = 0
      current_patch = 0
    when "q"
      abort("Aborting tag procedure")
    end

    puts LINE_BUFFER
    puts " The current tag is: [#{ current_tag }]"
    puts " Updating tag to be: [#{current_major}.#{current_minor}."\
    "#{current_patch}]"
    puts LINE_BUFFER

    if confirm " #{ YELLOW }Is this correct? (#{WHITE}y#{YELLOW}/#{WHITE}n"\
    "#{YELLOW}) "
      new_tag = "#{current_major}.#{current_minor}.#{current_patch}"
    else
      abort("Aborting tag procedure")
    end
  end

  desc "Create a changelog entry and commit to master"
  task :create_change_log do
    if confirm " Would you like to create and commit a changelog message " \
    "related to your new tag? (y/n) "
      puts LINE_BUFFER
      puts " The following commits were made since the last tag was created"
      puts DIVIDER_BLUE
      print `git log --since="#{ current_tag_date }" --pretty=format:'%Cblue %ci %Creset-%Cred %an%Creset - %s'`
      puts DIVIDER_BLUE
      puts " #{ YELLOW }Enter a brief changelog message to describe the " \
      "updates since the last tag was created, then press [#{WHITE}ENTER" \
      "#{YELLOW}]#{DEFAULT_COLOR}"
      changelog_message = STDIN.gets.strip
      puts LINE_BUFFER
      puts "#{ YELLOW } The following will be prefixed to the CHANGELOG.md " \
      "file #{DEFAULT_COLOR}"
      puts "## #{ new_tag } - #{ DateTime.now.strftime('%F') }"
      puts "  * #{ changelog_message }"
      puts LINE_BUFFER
      complete_changelog_update = "## #{ new_tag } - " \
      "#{ DateTime.now.strftime('%F') }\n * #{ changelog_message }\n\n"

      if RAILS_APPLICATION != project_type
        update_gem_version project_type
      end

      if confirm "#{ YELLOW } Are you sure that you would like to commit " \
      "this change to origin/master before creating the new tag? (#{WHITE}y" \
      "#{YELLOW}/#{WHITE}n#{YELLOW})#{DEFAULT_COLOR} "
        modify_changelog(complete_changelog_update)
      else
        abort("Aborting tagging process.")
      end
    end
  end

  desc "Create and push new tag"
  task :create_and_push_tag do
    puts "Creating and pushing new tag..."
    `git tag #{ new_tag }`
    `git push origin #{ new_tag }`
    puts "#{ WHITE }Tag creation complete! #{ DEFAULT_COLOR }"
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

  def modify_changelog(message)
    original_changelog = locate_changelog
    new_changelog = "#{original_changelog}.new"

    File.open(new_changelog, "w") do |fo|
      fo.puts message
      File.foreach(original_changelog) do |li|
        fo.puts li
      end
    end
    File.rename(new_changelog, original_changelog)

    `git add "#{original_changelog}"`
    `git commit -m "Updating changelog for latest tag."`
    if confirm "push the changelog update to the repository? (#{WHITE}y" \
      "#{YELLOW}/#{WHITE}n#{YELLOW})#{DEFAULT_COLOR} "
      `git push`
    end
  end

  def locate_changelog
    if defined? Rails
      puts "checking for changelog file relative to Rails app ..."
      changelog = File.expand_path(Rails.root.join "CHANGELOG.md")
      if File.file?(changelog)
        puts "found Rails application changelog location ..."
        project_type = RAILS_APPLICATION
        return changelog
      end

      changelog = File.expand_path(Rails.root.join "../../CHANGELOG.md")
      if File.file?(changelog)
        puts "found Rails Gem changelog location ..."
        project_type = RAILS_GEM
        return changelog
      end
    else
      changelog = File.join(File.dirname(File.expand_path(__FILE__)),
                            "../../../../CHANGELOG.md")
      if File.file?(changelog)
        puts "found changelog file relative to non-rails dummy app ..."
        project_type = NON_RAILS_GEM
        return changelog
      end

      changelog = File.join(File.dirname(File.expand_path(__FILE__)),
                            "../../CHANGELOG.md")
      if File.file?(changelog)
        puts "found changelog file relative to a gem without rails ..."
        project_type = GIT_TRIGGER_GEM
        return changelog
      end
    end
    puts "no changelog file could be found to update"
    abort("aborting tagging process")
  end

  # Updates a Gems version to match the new tag
  def update_gem_version (project_name, project_type, updated_version)

    # Determine version file location
    if GIT_TRIGGER_GEM == project_type
      version_file = File.join(File.dirname(File.expand_path(__FILE__)),
                            "../../lib/git_trigger/version.rb")
    elsif RAILS_GEM == project_type
      project_name = Rails.application.class.parent_name.underscore
      version_file = File.expand_path(Rails.root.join "../../lib/" \
                     "#{ project_name }/version.rb")
    elsif NON_RAILS_GEM == project_type
      #TODO Add logic to find gem name and apply to version_file path
      project_name = "PLACE_HOLDER"
      version_file = File.join(File.dirname(File.expand_path(__FILE__)),
                            "../../../../lib/#{ project_name }/version.rb")
    end

    # Update version number
    version_text = File.read(version_file)
    updated_version_contents = version_text.gsub(/  VERSION = "*"/, "  VERSION = #{ updated_version }")
    File.open(file_name, "w") {|file| file.puts updated_version_contents }
    abort("test")
  end

end
