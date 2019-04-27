require "spec_helper"

describe Harpy do
  after{ Harpy.reset }

  it "defaults to Harpy::Client" do
    expect(Harpy.client).to be_kind_of Harpy::Client
  end

  it "does allow using another client" do
    custom_client = double
    Harpy.client = custom_client
    expect(Harpy.client).to be custom_client
  end

  it "has no default entry_point_url" do
    expect(Harpy.entry_point_url).to be_nil
  end

  it "does allow setting an entry_point_url" do
    Harpy.entry_point_url = "http://localhost"
    expect(Harpy.entry_point_url).to eq("http://localhost")
  end

  it "raises Harpy::EntryPointRequired when trying to access entry_point and none has been created yet" do
    expect{ Harpy.entry_point }.to raise_error Harpy::EntryPointRequired
  end

  it "returns a valid Harpy::EntryPoint object if entry_point_url has been set" do
    Harpy.entry_point_url = "http://localhost"
    expect(Harpy.entry_point).to be_kind_of Harpy::EntryPoint
    expect(Harpy.entry_point.url).to eq("http://localhost")
  end

  it "does allow setting entry_point manually" do
    Harpy.entry_point = (entry_point = double)
    expect(Harpy.entry_point).to be entry_point
    expect(entry_point).to receive(:url).and_return "http://localhost"
    expect(Harpy.entry_point_url).to eq("http://localhost")
  end

  it "Harpy.reset clears both client and entry_point" do
    Harpy.entry_point_url = "http://localhost"
    Harpy.client = (custom_client = double)
    Harpy.reset
    expect(Harpy.entry_point_url).to be_nil
    expect(Harpy.client).not_to be custom_client
  end
end

describe Harpy::Exception do
  it "is an ::Exception" do
    expect(Harpy::Exception.ancestors).to include ::Exception
  end
end

describe Harpy::EntryPointRequired do
  it "is an Harpy::Exception" do
    expect(Harpy::EntryPointRequired.ancestors).to include Harpy::Exception
  end
end

describe Harpy::UrlRequired do
  it "is an Harpy::Exception" do
    expect(Harpy::UrlRequired.ancestors).to include Harpy::Exception
  end
end

describe Harpy::BodyToBig do
  it "is an Harpy::Exception" do
    expect(Harpy::BodyToBig.ancestors).to include Harpy::Exception
  end
end

describe Harpy::ClientTimeout do
  it "is an Harpy::Exception" do
    expect(Harpy::ClientTimeout.ancestors).to include Harpy::Exception
  end
end

describe Harpy::ClientError do
  it "is an Harpy::Exception" do
    expect(Harpy::ClientError.ancestors).to include Harpy::Exception
  end
end

describe Harpy::Unauthorized do
  it "is an Harpy::Exception" do
    expect(Harpy::Unauthorized.ancestors).to include Harpy::Exception
  end
end

describe Harpy::InvalidResponseCode do
  it "is an Harpy::Exception" do
    expect(Harpy::InvalidResponseCode.ancestors).to include Harpy::Exception
  end
end
