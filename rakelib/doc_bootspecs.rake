namespace :doc do
  desc "Build boot requirements spec."
  task :bootspecs do
    files = Dir["**/test/boot_requirements_checker_*_test.rb"]
    sh "rspec" \
      " --require ./src/tools/md_formatter.rb" \
      " --format MdFormatter" \
      " --out doc/boot-requirements.md" \
      " '#{files.join("' '")}'" unless files.empty?
  end
end
