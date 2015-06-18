require "rails_helper"

describe Paper do

  let(:arxiv_doc) {
    stub_request(:get, "http://export.arxiv.org/api/query?id_list=1311.1653v2").to_return(fixture('arxiv/1311.1653v2.xml'))
    Arxiv.get('1311.1653v2')
  }

  it "should initialize properly" do
    paper = create(:paper)

    assert !paper.sha.nil?
    expect(paper.sha.length).to eq(32)
    expect(paper.state).to eq("submitted")
  end

  describe "construction" do

    it "Adds the submittor and editor as assignments" do
      editor    = set_paper_editor
      submittor = create(:user)
      p = create(:paper, submittor:submittor)

      expect(p.submittor_assignment.user).to eq(submittor)
      expect(p.assignments.length).to eq(2)
      expect(p.assignments.first.role).to  eq('editor')
      expect(p.assignments.first.user).to  eq(editor)
      expect(p.assignments.second.role).to eq('submittor')
      expect(p.assignments.second.user).to eq(submittor)
    end

    it "should build a paper from an arxiv document" do
      stub_request(:get, "http://export.arxiv.org/api/query?id_list=1311.1653").
          to_return(fixture("arxiv/1311.1653v2.xml"))

      doc = Arxiv.get('1311.1653')
      p = Paper.new_for_arxiv(doc)

      expect(p.arxiv_id).to eq('1311.1653')
      expect(p.version).to eq(2)
      expect(p.title).to eq("A photometric comprehensive study of circumnuclear star forming rings: the sample")
      expect(p.summary).to match /^We present.*paper.$/
      expect(p.location).to eq("http://arxiv.org/pdf/1311.1653v2.pdf")
      expect(p.author_list).to eq("Mar Álvarez-Álvarez, Angeles I. Díaz")
    end

    it "should include additional attributes when building a paper from an arxiv document" do

      stub_request(:get, "http://export.arxiv.org/api/query?id_list=1311.1653").
          to_return(fixture("arxiv/1311.1653v2.xml"))

      doc = Arxiv.get('1311.1653')

      u = create(:user)
      p = Paper.new_for_arxiv(doc, submittor:u)

      expect(p.submittor).to eq(u)
    end

    it "should build a paper from an arxiv_id" do

      stub_request(:get, "http://export.arxiv.org/api/query?id_list=1311.1653").
                   to_return(fixture("arxiv/1311.1653v2.xml"))

      p = Paper.new_for_arxiv_id('1311.1653')

      expect(p.arxiv_id).to eq('1311.1653')
      expect(p.version).to eq(2)
      expect(p.title).to eq("A photometric comprehensive study of circumnuclear star forming rings: the sample")
      expect(p.summary).to match /^We present.*paper.$/
      expect(p.location).to eq("http://arxiv.org/pdf/1311.1653v2.pdf")
      expect(p.author_list).to eq("Mar Álvarez-Álvarez, Angeles I. Díaz")
    end

    it "should build a paper from an arxiv_id with a version" do

      stub_request(:get, "http://export.arxiv.org/api/query?id_list=1311.1653v2").
          to_return(fixture("arxiv/1311.1653v2.xml"))

      p = Paper.new_for_arxiv_id('1311.1653v2')

      expect(p.arxiv_id).to eq('1311.1653')
      expect(p.version).to eq(2)
    end

    it "should include additional attributes when building a paper from an arxiv_id" do

      stub_request(:get, "http://export.arxiv.org/api/query?id_list=1311.1653").
          to_return(fixture("arxiv/1311.1653v2.xml"))

      u = create(:user)
      p = Paper.new_for_arxiv_id('1311.1653', submittor:u)

      expect(p.submittor).to eq(u)
    end

    it "should raise an error if the arxiv id is not found" do
      stub_request(:get, "http://export.arxiv.org/api/query?id_list=0000.0000").
          to_return(fixture("arxiv/not_found.xml"))

      expect { Paper.new_for_arxiv_id('0000.0000') }.to raise_exception(Arxiv::Error::ManuscriptNotFound)
    end

  end

  describe "emails" do

    it "sends an email to the submittor" do
      user = create(:user, name:'John Smith', email:'jsmith@example.com')
      expect {
        create(:paper, title:'My Paper', submittor:user)
      }.to change { deliveries.size }.by(1)

      is_expected.to have_sent_email.to('jsmith@example.com').matching_subject(/My Paper - Paper Submitted/)
    end

    it "sends an email to the submittor when it is revised" do
      user = create(:user, name:'John Smith', email:'jsmith@example.com')
      original = create(:paper, title:'My Paper', submittor:user, arxiv_id:'1311.1653', version:1, submittor:user)
      deliveries.clear

      expect {
        Paper.create_updated!(original, arxiv_doc)
      }.to change { deliveries.size }.by(1)

      is_expected.to have_sent_email.to('jsmith@example.com').matching_subject(/A photo.* - Paper Revised/)
    end

    it "sends an email when the state changes" do
      user  = create(:user, name:'John Smith', email:'jsmith@example.com')
      paper = create(:paper, title:'My Paper', submittor:user, reviewer:true)
      deliveries.clear

      expect {
        paper.start_review!
      }.to change { deliveries.size }.by(1)

      is_expected.to have_sent_email.to('jsmith@example.com').matching_subject(/Paper Under Review/)

      expect {
        paper.complete_review!
      }.to change { deliveries.size }.by(1)

    end

    it "doesn't send an email when the paper is superceded" do
      user  = create(:user, name:'John Smith', email:'jsmith@example.com')
      paper = create(:paper, title:'My Paper', submittor:user)
      deliveries.clear

      expect {
        paper.supercede!
      }.not_to change { deliveries.size }
    end

    it "doesn't send an email when the state doesn't change" do
      user  = create(:user, name:'John Smith', email:'jsmith@example.com')
      paper = create(:paper, title:'My Paper', submittor:user)
      deliveries.clear

      expect {
        paper.update_attributes!(title:'A new title')
      }.not_to change { deliveries.size }
    end

  end

  describe "::with_scope" do

    it "should return properly scoped records" do
      paper = create(:paper, :submitted)
      create(:paper)

      assert_equal Paper.count, 2
      assert_includes Paper.with_state('submitted'), paper
    end

  end

  describe "::versions_for" do

    it "should return a sorted list of papers" do
      create(:paper, arxiv_id:'9999.9999', version:2)
      create(:paper, arxiv_id:'1234.5678', version:2)
      create(:paper, arxiv_id:'1234.5678', version:1)
      create(:paper, arxiv_id:'1234.5678', version:3)
      create(:paper, arxiv_id:'1234.5678', version:4)

      papers = Paper.versions_for('1234.5678')

      expect(papers[0]['version']).to eq(4)
      expect(papers[1]['version']).to eq(3)
      expect(papers[2]['version']).to eq(2)
      expect(papers[3]['version']).to eq(1)
    end

  end

  describe "::create_updated!" do

    it "should create a new instance" do
      original  = create(:paper, arxiv_id:'1311.1653')
      new_paper = nil
      expect {
        new_paper = Paper.create_updated!(original, arxiv_doc)
      }.to change{Paper.count}.by(1)

      expect(new_paper).to be_persisted
    end

    it "should change the state of the original instance to superceded" do
      original  = create(:paper, arxiv_id:'1311.1653')
      new_paper = Paper.create_updated!(original, arxiv_doc)

      expect(original).to be_superceded
    end

    it "should copy the attributes from the original paper" do
      original  = create(:paper, :under_review, arxiv_id:'1311.1653')
      new_paper = Paper.create_updated!(original, arxiv_doc)

      expect(new_paper.submittor).to eq(original.submittor)
      expect(new_paper.state).to     eq('under_review')
    end

    it "should set the arxiv attributes on the new paper" do
      original  = create(:paper, arxiv_id:'1311.1653')
      new_paper = Paper.create_updated!(original, arxiv_doc)

      expect(new_paper.arxiv_id).to eq('1311.1653')
      expect(new_paper.version).to eq(2)
      expect(new_paper.title).to eq("A photometric comprehensive study of circumnuclear star forming rings: the sample")
      expect(new_paper.summary).to match /^We present.*paper.$/
      expect(new_paper.location).to eq("http://arxiv.org/pdf/1311.1653v2.pdf")
      expect(new_paper.author_list).to eq("Mar Álvarez-Álvarez, Angeles I. Díaz")
    end

    it "should copy the assignments from the original paper" do
      set_paper_editor
      original  = create(:paper, arxiv_id:'1311.1653',
                         reviewer:[ create(:user), create(:user) ])
      expect(original.assignments.length).to eq(4)

      new_paper = Paper.create_updated!(original, arxiv_doc)

      expect(new_paper.assignments.length).to eq(original.assignments.length)
      (0...original.assignments.length).each do |index|
        expect(new_paper.assignments[index].role).to eq(original.assignments[index].role)
        expect(new_paper.assignments[index].user).to eq(original.assignments[index].user)
        expect(new_paper.assignments[index].updated).to be_truthy
      end

    end

    it "should keep the public attribute on the assignments if it is set on the original paper" do
      original  = create(:paper, arxiv_id:'1311.1653',
                         reviewer:[ create(:user), create(:user) ])
      original.assignments.second.update_attributes!(public:true)

      new_paper = Paper.create_updated!(original, arxiv_doc)

      expect(new_paper.assignments.second.public).to be_truthy
      expect(new_paper.assignments.third.public).to be_falsy
    end

    it "should NOT keep the completed attribute on the assignments if it is set on the original paper" do
      original  = create(:paper, arxiv_id:'1311.1653',
                         reviewer:[ create(:user), create(:user) ])
      original.assignments.second.update_attributes!(completed:true)

      new_paper = Paper.create_updated!(original, arxiv_doc)

      expect(new_paper.assignments.second.public).to be_falsy
    end

    it "should copy the original editor" do
      set_paper_editor
      original  = create(:paper, arxiv_id:'1311.1653',
                         reviewer:[ create(:user), create(:user) ])
      expect(original.assignments.length).to eq(4)

      set_paper_editor
      new_paper = Paper.create_updated!(original, arxiv_doc)

      expect(new_paper.assignments.length).to eq(original.assignments.length)
      (0...original.assignments.length).each do |index|
        expect(new_paper.assignments[index].role).to eq(original.assignments[index].role)
        expect(new_paper.assignments[index].user).to eq(original.assignments[index].user)
      end

    end

    it "should raise an error if the arxiv_ids are different" do
      original  = create(:paper, arxiv_id:'9999.9999')
      expect { Paper.create_updated!(original, arxiv_doc) }.to raise_exception
    end

    it "should raise an error if the original cannot be superceded" do
      original  = create(:paper, arxiv_id:'1311.1653')

      expect { Paper.create_updated!(original, arxiv_doc) }.not_to raise_exception

      original.state = 'superceded'
      expect { Paper.create_updated!(original, arxiv_doc) }.to raise_exception
      original.state = 'resolved'
      expect { Paper.create_updated!(original, arxiv_doc) }.to raise_exception
    end

    it "should raise an error if there is no new arxiv version" do
      original  = create(:paper, arxiv_id:'1311.1653', version:2)
      expect { Paper.create_updated!(original, arxiv_doc) }.to raise_exception
    end

  end

  context "versioning" do

    def create_papers
       @paper1 = create(:paper, arxiv_id:'123', version:1, state:'superceded')
       @paper2 = create(:paper, arxiv_id:'123', version:2, state:'superceded')
       @paper3 = create(:paper, arxiv_id:'123', version:3)
    end

    describe "#is_original_version?" do

      it "should work for a single paper" do
        @paper1 = create(:paper, arxiv_id:'123', version:2)
        expect(@paper1.is_original_version?).to be_truthy
      end

      it "should work for multiple papers" do
        create_papers
        expect(@paper1.is_original_version?).to be_truthy
        expect(@paper2.is_original_version?).to be_falsey
        expect(@paper3.is_original_version?).to be_falsey
      end

    end

    describe "#is_latest_version?" do

      it "should work for a single paper" do
        @paper1 = create(:paper, arxiv_id:'123', version:2)
        expect(@paper1.is_latest_version?).to be_truthy
      end

      it "should work for multiple papers" do
        create_papers
        expect(@paper1.is_latest_version?).to be_falsey
        expect(@paper2.is_latest_version?).to be_falsey
        expect(@paper3.is_latest_version?).to be_truthy
      end

    end

    describe "#is_revision?" do

      it "should work for a single paper" do
        @paper1 = create(:paper, arxiv_id:'123', version:2)
        expect(@paper1.is_revision?).to be_falsey
      end

      it "should work for multiple papers" do
        create_papers
        expect(@paper1.is_revision?).to be_falsey
        expect(@paper2.is_revision?).to be_truthy
        expect(@paper3.is_revision?).to be_truthy
      end

    end

  end

  describe "states" do

    context "begin_review event" do

      it "should succeed if the paper has reviewers" do
        paper = create(:paper, reviewer:true)
        paper.start_review!
      end

      it "should fail if the paper has no reviewers" do
        paper = create(:paper)
        expect { paper.start_review! }.to raise_exception(AASM::InvalidTransition)
      end

    end

  end

  describe "#resolve_all_issues" do

    it "should resolve any outstanding issues" do
      paper = create(:paper, :under_review)
      3.times { create(:annotation, paper:paper) }

      expect(paper.annotations.count).to eq(3)

      paper.resolve_all_issues

      expect( paper.outstanding_issues ).to be_empty
    end

  end

  describe "Abilities" do

    it "should allow a user to create a Paper as author" do
      user = create(:user)
      ability = Ability.new(user)

      assert ability.can?(:create, Paper.create!(submittor:user))
    end

    it "should allow a user to read a Paper as author" do
      user = create(:user)
      paper = create(:paper, submittor:user)

      ability = Ability.new(user, paper)

      assert ability.can?(:read, paper)
    end

    # it "should allow a user to update their own paper if it's not submitted" do
    #   user = create(:user)
    #   paper = create(:paper, submittor:user)
    #
    #   ability = Ability.new(user, paper)
    #
    #   assert ability.can?(:update, paper)
    # end

    it "should not allow a user to update their own paper" do
      user = create(:user)
      paper = create(:paper, :submitted, submittor:user)

      ability = Ability.new(user, paper)

      assert ability.cannot?(:update, paper)
    end

    # it "can destroy a draft paper that a user owns" do
    #   user = create(:user)
    #   paper = create(:paper, submittor:user)
    #
    #   ability = Ability.new(user, paper)
    #
    #   assert ability.can?(:destroy, paper)
    # end

    it "cannot destroy a draft paper that a user doesn't own" do
      user = create(:user)
      paper = create(:paper)

      ability = Ability.new(user, paper)

      assert ability.cannot?(:destroy, paper)
    end

    it "cannot destroy a submitted paper that a user owns" do
      user  = create(:user)
      paper = create(:paper, :submitted, submittor:user)

      ability = Ability.new(user, paper)

      assert ability.cannot?(:destroy, paper)
    end

    it "an editor can change the state of a paper" do
      user  = create(:editor)
      paper = create(:paper, :submitted, submittor:create(:user))

      ability = Ability.new(user, paper)

      expect(ability).to be_able_to(:start_review, paper)
    end

    it "an author cannot change the state of a paper" do
      user = create(:user)
      paper = create(:paper, :submitted, submittor:user)

      ability = Ability.new(user, paper)

      expect(ability).not_to be_able_to(:start_review, paper)
    end

    it "a reviewer cannot change the state of a paper" do
      user = create(:user)
      paper = create(:paper, :submitted, submittor:create(:user), reviewer:user )

      ability = Ability.new(user, paper)

      expect(ability).not_to be_able_to(:start_review, paper)
    end

    it "a reader cannot change the state of a paper" do
      user = create(:user)
      paper = create(:paper, :submitted, submittor:create(:user) )

      ability = Ability.new(user, paper)

      expect(ability).not_to be_able_to(:start_review, paper)
    end

  end

  describe "#permisions_for_user" do

    it "should return correct permissions for paper for user" do
      user = create(:user)
      paper = create(:paper, submittor:user)

      create(:assignment, :reviewer,     user:user, paper:paper)
      create(:assignment, :collaborator, user:user, paper:paper)

      ["submittor", "collaborator", "reviewer"].each do |role|
        assert paper.permissions_for_user(user).include?(role), "Missing #{role}"
      end
    end

    it "should return correct permissions for paper for user as editor" do
      user  = set_paper_editor
      paper = create(:paper, submittor:user)

      create(:assignment, :reviewer,     user:user, paper:paper)
      create(:assignment, :collaborator, user:user, paper:paper)

      ["editor", "submittor", "collaborator", "reviewer"].each do |role|
        assert paper.permissions_for_user(user).include?(role), "Missing #{role}"
      end
    end

  end

  describe "#assignments" do

    describe "#for_user" do

      it "should return the assignmnet for a user" do
        submittor = create(:user)
        paper     = create(:paper, submittor:submittor)

        assignment = paper.assignments.for_user(submittor)
        expect(assignment.user).to eq(submittor)
      end

      it "should return the assignmnet for a user and role" do
        user   = create(:user)
        paper  = create(:paper, submittor:user, reviewer:user)

        assignment = paper.assignments.for_user(user, 'submittor')
        expect(assignment).to be_present
        expect(assignment.user).to eq(user)
        expect(assignment.role).to eq('submittor')

        assignment = paper.assignments.for_user(user, 'reviewer')
        expect(assignment).to be_present
        expect(assignment.user).to eq(user)
        expect(assignment.role).to eq('reviewer')
      end

    end

  end

  describe "#add_assignee" do

    it "should add the user as a reviewer" do
      user  = create(:user)
      paper = create(:paper)

      expect(paper.add_assignee(user,'reviewer')). to be_truthy
      expect(paper.reviewers.length).to eq(1)
      expect(paper.reviewers.first).to eq(user)
    end

    it "should fail if the user is the submittor" do
      user  = create(:user)
      paper = create(:paper, submittor:user)

      expect(paper.add_assignee(user,'reviewer')). to be_falsy
      expect(paper.reviewers).to be_empty
      expect(paper.errors).not_to be_empty
    end

    it "should fail if the user is a collaborator" do
      user  = create(:user)
      paper = create(:paper, collaborator:user)

      expect(paper.add_assignee(user,'reviewer')). to be_falsy
      expect(paper.reviewers).to be_empty
      expect(paper.errors).not_to be_empty
    end

    it "should fail if the user is already a reviewer" do
      user  = create(:user)
      paper = create(:paper, reviewer:user)

      expect(paper.add_assignee(user,'reviewer')). to be_falsy
      expect(paper.reviewers.length).to eq(1)
      expect(paper.errors).not_to be_empty
    end

  end

  describe "#mark_review_completed!" do

    let(:reviewers) { create_list(:user, 2) }

    it "should return an error if the paper is not in a reviewable state" do
      paper = create(:paper, reviewer:reviewers)

      expect(paper.mark_review_completed!(reviewers.first)).to be_falsy
      expect(paper.errors).to be_present
    end

    it "should return an error if the user is not a reviewer" do
      paper = create(:paper, :under_review, reviewer:true)

      expect(paper.mark_review_completed!(paper.submittor)).to be_falsy
      expect(paper.errors).to be_present
    end

    it "should mark the reviewer as completed" do
      paper = create(:paper, :under_review, reviewer:reviewers)

      expect(paper.mark_review_completed!(reviewers.first)).to be_truthy
      expect(paper.errors).to be_empty

      expect(paper.reviewer_assignments.first.completed).to be_truthy
      expect(paper).to be_under_review
    end

    it "when the last review is completed the state of the paper should change" do
      paper = create(:paper, :under_review, reviewer:reviewers)
      paper.reviewer_assignments.first.update_attributes(completed:true)

      expect(paper.mark_review_completed!(reviewers.second)).to be_truthy
      expect(paper.reviewer_assignments.second.completed).to be_truthy
      expect(paper).to be_review_completed
    end

    it "sends an email to the editor when the review is completed by all reviewers" do
      set_paper_editor create(:user, email:'editor@example.com')

      paper = create(:paper, :under_review, reviewer:reviewers)
      paper.reviewer_assignments.first.update_attributes(completed:true)

      expect {
        paper.mark_review_completed!(reviewers.second)
      }.to change { deliveries.count }.by(1)

      is_expected.to have_sent_email.to('editor@example.com').matching_subject(/- Review Completed/)
    end

  end


end
