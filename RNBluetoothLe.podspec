
Pod::Spec.new do |s|
  s.homepage = "https://facebook.github.io/react-native/"
  s.name         = "RNBluetoothLe"
  s.version      = "1.0.0"
  s.summary      = "RNBluetoothLe"
  s.description  = <<-DESC
                  RNBluetoothLe
                   DESC
  #s.homepage     = ""
  s.license      = "MIT"
  # s.license      = { :type => "MIT", :file => "FILE_LICENSE" }
  s.author             = { "author" => "author@domain.cn" }
  s.platform     = :ios, "10.0"
  s.source       = { :git => "https://github.com/author/RNBluetoothLe.git", :tag => "master" }
  s.source_files = "ios/*.{h,m}"
  s.requires_arc = true


  s.dependency "React"
  #s.dependency "others"

end

  
