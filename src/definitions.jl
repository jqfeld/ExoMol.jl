using JSON


function read_def_file(filename;)
  if endswith(filename, ".json")
    return JSON.parsefile(filename)
  end
  
end
