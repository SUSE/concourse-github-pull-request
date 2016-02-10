def mk_structs(obj)
  if obj.class == Array
    obj.map { |h| RecursiveOpenStruct.new(h) }
  else
    RecursiveOpenStruct.new(obj)
  end
end
