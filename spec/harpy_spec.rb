require "spec_helper"

describe Harpy do
end

describe Harpy::Exception do
  it "is an ::Exception" do
    Harpy::Exception.ancestors.should include ::Exception
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

describe Harpy::InvalidResponseCode do
  it "is an Harpy::Exception" do
    Harpy::InvalidResponseCode.ancestors.should include Harpy::Exception
  end
end