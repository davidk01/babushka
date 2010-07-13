require 'spec_support'
require 'sources_support'
require 'source_pool_support'

describe SourcePool, '#dep_for' do
  before {
    @source1 = Source.new nil, :name => 'source_1'
    @source1.stub!(:load!)
    @source2 = Source.new nil, :name => 'source_2'
    @source2.stub!(:load!)
    DepDefiner.load_context :source => @source1 do
      @dep1 = dep 'dep 1'
      @dep2 = dep 'dep 2'
    end
    DepDefiner.load_context :source => @source2 do
      @dep3 = dep 'dep 3'
      @dep4 = dep 'dep 4'
    end
    Base.sources.stub!(:current).and_return([@source1, @source2])
    Source.stub!(:present).and_return([@source1, @source2])
  }
  it "should look up the correct deps without namespacing" do
    Base.sources.dep_for('dep 1').should == @dep1
    Base.sources.dep_for('dep 4').should == @dep4
  end
  it "should find the dep when the namespace is correct" do
    Base.sources.dep_for('source_1:dep 1').should == @dep1
    Base.sources.dep_for('source_2:dep 4').should == @dep4
  end
  it "should not find the dep when the namespace is wrong" do
    Base.sources.dep_for('source_1:dep 3').should be_nil
    Base.sources.dep_for('source_2:dep 2').should be_nil
  end
end

describe SourcePool, '#template_for' do
  before {
    mock_sources
  }
  context "without namespacing" do
    it "should find templates in the anonymous source" do
      Base.sources.template_for('anonymous meta').should == @anonymous_meta
    end
    it "should find templates in the core source" do
      Base.sources.template_for('core_meta').should == @core_meta
    end
    it "should not find templates from non-default sources" do
      Base.sources.template_for('meta_1').should be_nil
      Base.sources.template_for('meta_3').should be_nil
    end
    context "with :from" do
      it "should find the template in the same source" do
        Base.sources.template_for('from test', :from => @source1).should == @from1
        Base.sources.template_for('from test', :from => @source2).should == @from2
      end
      context "when it doesn't exist in the :from source" do
        it "should find the template in the core source" do
          Base.sources.template_for('core from', :from => @source1).should == @core_from
        end
        it "should not find the template in other sources" do
          Base.sources.template_for('from test 2', :from => @source1).should be_nil
        end
      end
    end
  end
  context "with namespacing" do
    it "should find the dep when the namespace is correct" do
      Base.sources.template_for('source_1:meta_1').should == @meta1
      Base.sources.template_for('source_2:meta 4').should == @meta4
    end
    it "should not find the dep when the namespace is wrong" do
      Base.sources.template_for('source_1:').should be_nil
      Base.sources.template_for('source_2:meta 2').should be_nil
    end
  end
  after {
    Base.sources.anonymous.templates.clear!
    Base.sources.core.templates.clear!
  }
end

describe "template selection during defining" do
  before {
    mock_sources
  }
  context "with namespacing" do
    it "should use templates from the named source" do
      dep('template selection 1', :template => 'source_1:meta_1').template.should == @meta1
    end
    it "should not find the template with the wrong source prefix, and raise" do
      L{
        dep('template selection 2', :template => 'source_2:meta_1')
      }.should raise_error DepError, "There is no template named 'source_2:meta_1' to define 'template selection 2' against."
    end
  end
  context "without namespacing" do
    context "with :template option" do
      it "should find a template in the same source" do
        mock_dep('template selection 3', :template => 'meta_1', :in => @source1).template.should == @meta1
      end
      it "should not find a template in the wrong source, and raise" do
        L{
          mock_dep('template selection 4', :template => 'meta_3', :in => @source1)
          }.should raise_error DepError, "There is no template named 'meta_3' to define 'template selection 4' against."
      end
    end
    context "with suffixes" do
      it "should find a template in the same source" do
        mock_dep('template selection 3.meta_1', :in => @source1).template.should == @meta1
      end
      it "should find a template in the core source" do
        mock_dep('template selection 3.core_meta', :in => @source1).template.should == @core_meta
      end
      it "should not find a template in the wrong source, and use the base template" do
        mock_dep('template selection 4.meta_3', :in => @source1).template.should == Dep::BaseTemplate
      end
    end
  end
  after {
    Base.sources.anonymous.templates.clear!
    Base.sources.core.templates.clear!
  }
end
