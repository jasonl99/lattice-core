require "baked_file_system"
class PublicStorage
  BakedFileSystem.load("./public/",__DIR__)
end


puts PublicStorage.files.map &.path
