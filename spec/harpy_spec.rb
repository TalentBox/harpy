require "spec_helper"

describe Harpy do
  after{ Harpy.reset }

  it "defaults to Harpy::Client" do
    Harpy.client.should be_kind_of Harpy::Client
  end

  it "does allow using another client" do
    custom_client = mock
    Harpy.client = custom_client
    Harpy.client.should be custom_client
  end

  it "has no default entry_point_url" do
    Harpy.entry_point_url.should be_nil
  end

  it "does allow setting an entry_point_url" do
    Harpy.entry_point_url = "http://localhost"
    Harpy.entry_point_url.should == "http://localhost"
  end

  it "raises Harpy::EntryPointRequired when trying to access entry_point and none has been created yet" do
    lambda{ Harpy.entry_point }.should raise_error Harpy::EntryPointRequired
  end

  it "returns a valid Harpy::EntryPoint object if entry_point_url has been set" do
    Harpy.entry_point_url = "http://localhost"
    Harpy.entry_point.should be_kind_of Harpy::EntryPoint
    Harpy.entry_point.url.should == "http://localhost"
  end

  it "does allow setting entry_point manually" do
    Harpy.entry_point = (entry_point = mock)
    Harpy.entry_point.should be entry_point
    entry_point.should_receive(:url).and_return "http://localhost"
    Harpy.entry_point_url.should == "http://localhost"
  end

  it "Harpy.reset clears both client and entry_point" do
    Harpy.entry_point_url = "http://localhost"
    Harpy.client = (custom_client = mock)
    Harpy.reset
    Harpy.entry_point_url.should be_nil
    Harpy.client.should_not be custom_client
  end
end

describe Harpy::Exception do
  it "is an ::Exception" do
    Harpy::Exception.ancestors.should include ::Exception
  end
end

describe Harpy::EntryPointRequired do
  it "is an Harpy::Exception" do
    Harpy::EntryPointRequired.ancestors.should include Harpy::Exception
  end
end

describe Harpy::UrlRequired do
  it "is an Harpy::Exception" do
    Harpy::UrlRequired.ancestors.should include Harpy::Exception
  end
end

describe Harpy::BodyToBig do
  it "is an Harpy::Exception" do
    Harpy::BodyToBig.ancestors.should include Harpy::Exception
  end
end

describe Harpy::ClientTimeout do
  it "is an Harpy::Exception" do
    Harpy::ClientTimeout.ancestors.should include Harpy::Exception
  end
end

describe Harpy::ClientError do
  it "is an Harpy::Exception" do
    Harpy::ClientError.ancestors.should include Harpy::Exception
  end
end

describe Harpy::Unauthorized do
  it "is an Harpy::Exception" do
    Harpy::Unauthorized.ancestors.should include Harpy::Exception
  end
end

describe Harpy::InvalidResponseCode do
  it "is an Harpy::Exception" do
    Harpy::InvalidResponseCode.ancestors.should include Harpy::Exception
  end
end