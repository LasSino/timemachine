Gem::Specification.new do |s|
  s.name        = "timemachine"
  s.version     = "1.0.2"
  s.summary     = "A library that executes task after timeup or timeout."
  s.description = "A library that executes task after timeup or timeout. Zero dependency and concurrent-safe."
  s.authors     = ["LTW"]
  s.email       = "ltwsamuel@outlook.com"
  s.files       = [
    "lib/timemachine.rb",
    "lib/thread_executor.rb",
    "lib/executor.rb"
  ]
  s.required_ruby_version = ">= 2.4"
  s.homepage    =
    "https://github.com/LasSino/timemachine"
  s.license       = "MIT"
end