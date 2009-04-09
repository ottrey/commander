
class Array 
  
  ##
  # Split +string+ into an array. Used in
  # conjunction with Highline's ask, or ask_for_array
  # methods, which must respond to #parse.
  #
  # === Highline example
  #  
  #   # ask invokes Array#parse
  #   list = ask 'Favorite cookies:', Array
  #
  #   # or use ask_for_CLASS
  #   list = ask_for_array 'Favorite cookies: '
  #
  
  def self.parse string
    eval "%w(#{string})"
  end
  
  ##
  # Delete switches such as -h or --help. Mutative.
  
  def delete_switches
    self.delete_if { |value| value.to_s =~ /^-/ } 
  end
  
end
