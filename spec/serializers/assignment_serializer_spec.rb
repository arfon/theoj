require "rails_helper"

describe AssignmentSerializer do

  it "should initialize properly" do
    assignment = create(:assignment)
    serializer = AssignmentSerializer.new(assignment)
    hash = hash_from_json(serializer.to_json)

    expect(hash.keys).to contain_exactly('role', 'sha', 'user', 'public')
  end

  it "A reviewer should include the completed field" do
    assignment = create(:assignment, :reviewer)
    serializer = AssignmentSerializer.new(assignment)
    hash = hash_from_json(serializer.to_json)

    expect(hash.keys).to contain_exactly('role', 'sha', 'completed', 'public')
  end

  it "A reviewer should include the reviewer_accept field when completed" do
    assignment = create(:assignment, :reviewer, completed:true, reviewer_accept:'accept_with_minor')
    serializer = AssignmentSerializer.new(assignment)
    hash = hash_from_json(serializer.to_json)

    expect(hash.keys).to include('reviewer_accept')
  end

  it "Non-reviewers should not include the completed field" do
    assignment = create(:assignment, :editor)
    serializer = AssignmentSerializer.new(assignment)
    hash = hash_from_json(serializer.to_json)

    expect(hash).not_to include('completed')
  end

  it "should include user info based on the role when no user is logged in" do
    user       = create(:user, name:'John Doe')

    assignment = create(:assignment, user:user, role:'submittor')
    serializer = AssignmentSerializer.new(assignment)
    hash = hash_from_json(serializer.to_json)
    expect(hash['user']).to include('name' => 'John Doe')

    assignment = create(:assignment, user:user, role:'collaborator')
    serializer = AssignmentSerializer.new(assignment)
    hash = hash_from_json(serializer.to_json)
    expect(hash['user']).to include('name' => 'John Doe')

    assignment = create(:assignment, user:user, role:'editor')
    serializer = AssignmentSerializer.new(assignment)
    hash = hash_from_json(serializer.to_json)
    expect(hash['user']).to include('name' => 'John Doe')

    assignment = create(:assignment, user:user, role:'reviewer')
    serializer = AssignmentSerializer.new(assignment)
    hash = hash_from_json(serializer.to_json)
    expect(hash['user']).to be_nil

  end

  it "should include user info based on the role when a normal user is logged in" do
    current_user = create(:user)
    user         = create(:user, name:'John Doe')

    assignment = create(:assignment, user:user, role:'submittor')
    serializer = AssignmentSerializer.new(assignment, scope:current_user)
    hash = hash_from_json(serializer.to_json)
    expect(hash['user']).to include('name' => 'John Doe')

    assignment = create(:assignment, user:user, role:'collaborator')
    serializer = AssignmentSerializer.new(assignment, scope:current_user)
    hash = hash_from_json(serializer.to_json)
    expect(hash['user']).to include('name' => 'John Doe')

    assignment = create(:assignment, user:user, role:'editor')
    serializer = AssignmentSerializer.new(assignment, scope:current_user)
    hash = hash_from_json(serializer.to_json)
    expect(hash['user']).to include('name' => 'John Doe')

    assignment = create(:assignment, user:user, role:'reviewer')
    serializer = AssignmentSerializer.new(assignment, scope:current_user)
    hash = hash_from_json(serializer.to_json)
    expect(hash['user']).to be_nil
  end

  it "should include reviewer info when the editor is logged in" do
    current_user = set_paper_editor

    user       = create(:user, name:'John Doe')
    assignment = create(:assignment, :reviewer, user:user)
    serializer = AssignmentSerializer.new(assignment, scope:current_user)

    hash = hash_from_json(serializer.to_json)
    expect(hash['user']).to include('name' => 'John Doe')
  end

  it "should include reviewer info when the reviewer is logged in" do
    user       = create(:user, name:'John Doe')
    assignment = create(:assignment, :reviewer, user:user)
    serializer = AssignmentSerializer.new(assignment, scope:user)

    hash = hash_from_json(serializer.to_json)
    expect(hash['user']).to include('name' => 'John Doe')
  end

  it "should include reviewer info when the assignment is made public" do
    current_user = create(:user)
    user         = create(:user, name:'John Doe')

    assignment = create(:assignment, user:user, role:'reviewer')
    serializer = AssignmentSerializer.new(assignment, scope:current_user)
    hash = hash_from_json(serializer.to_json)
    expect(hash['user']).to be_nil

    assignment.public = true
    hash = hash_from_json(serializer.to_json)
    expect(hash['user']).to include('name' => 'John Doe')
  end

end
