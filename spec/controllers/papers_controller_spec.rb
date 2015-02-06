require "rails_helper"

describe PapersController do

  describe "GET #index" do

    it "AS ADMIN responds successfully with an HTTP 200 status code" do
      authenticate(:admin)

      get :index, :format => :json
      expect(response).to have_http_status(:success)
      expect(response.status).to eq(200)
      expect(response.content_type).to eq("application/json")
    end

    it "AS NO USER responds successfully with an HTTP 200 status code but an empty body" do
      create(:paper)

      get :index, :format => :json
      expect(response).to have_http_status(:success)
      expect(response.status).to eq(200)
      expect(response.content_type).to eq("application/json")
    end

  end

  describe "GET #show" do

    it "AS USER without permissions" do
      authenticate
      paper = create(:paper)

      get :show, :id => paper.sha, :format => :json

      expect(response.status).to eq(403)
    end

    it "AS REVIEWER (with permissions)" do
      user = authenticate
      paper = create(:paper_under_review)
      create(:assignment_as_reviewer, :paper => paper, :user => user)

      get :show, :id => paper.sha, :format => :json

      expect(response).to have_http_status(:success)
      expect(response.status).to eq(200)
      expect(response.content_type).to eq("application/json")
    end

    it "AS COLLABORATOR (with permissions)" do
      user = authenticate
      paper = create(:paper_under_review)
      create(:assignment_as_collaborator, :paper => paper, :user => user)

      get :show, :id => paper.sha, :format => :json

      expect(response).to have_http_status(:success)
      expect(response.status).to eq(200)
      expect(response.content_type).to eq("application/json")
    end

    it "AS AUTHOR (with permissions)" do
      user = authenticate
      paper = create(:paper_under_review, :user => user)

      get :show, :id => paper.sha, :format => :json

      expect(response).to have_http_status(:success)
      expect(response.status).to eq(200)
      expect(response.content_type).to eq("application/json")
    end

  end

  describe "GET #arXiv_details" do

    let(:arxiv_response) do
      {
          "arxiv_url"        => "http://arxiv.org/abs/1111.1111v1",
          "created_at"       => "2011-11-04T12:50:44.000+00:00",
          "updated_at"       => "2011-11-04T12:50:44.000+00:00",
          "title"            => "Electronic structure of nickelates: From two-dimensional heterostructures to three-dimensional bulk materials",
          "summary"          => "Reduced dimensionality and strong electronic correlations, which are among the most important ...",
          "comment"          => "8 pages, 9 figures",
          "primary_category" => {"abbreviation" => "cond-mat.str-el"},
          "categories"       => [ {"abbreviation" => "cond-mat.str-el"} ],
          "authors"          => [ {"name" => "P. Hansmann", "affiliations" => []},
                                  {"name" => "K. Held",     "affiliations" => []}  ],
          "links"            => [ {"url"  => "http://dx.doi.org/10.1103/PhysRevB.82.235123", "content_type" => ""},
                                  {"url"  => "http://arxiv.org/abs/1111.1111v1",             "content_type" => "text/html"},
                                  {"url"  => "http://arxiv.org/pdf/1111.1111v1",             "content_type" => "application/pdf"} ]
      }
    end

    it "should fail if no user is logged in" do
      expect(Arxiv).not_to receive(:get)

      get :arXiv_details, :id => '1234.5678', :format => :json

      expect(response).to have_http_status(:forbidden)
      expect(response_json).to be_empty
    end

    it "should succeed if the user is logged in" do
      authenticate
      expect(Arxiv).to receive(:get).with('1234.5678').and_return(arxiv_response)

      get :arXiv_details, :id => '1234.5678', :format => :json

      expect(response).to have_http_status(:success)
      expect(response.content_type).to eq("application/json")
      expect(response_json).to eq(arxiv_response)
    end

    it "should return a 404 if the paper is not found on Arxiv" do
      authenticate
      expect(Arxiv).to receive(:get).and_raise(Arxiv::Error::ManuscriptNotFound)

      get :arXiv_details, :id => '1234.5678', :format => :json

      expect(response).to have_http_status(:not_found)
    end

  end

  describe "GET #status" do

    render_views

    it "WITHOUT USER responds successfully with an HTTP 200 status code" do
      paper = create(:paper_under_review)
      get :status, :id => paper.sha, :format => :html

      etag1 = response.header['ETag']

      expect(response).to have_http_status(:success)
      expect(response.status).to eq(200)
      expect(response.content_type).to eq("text/html")
      assert response.body.include?('review.svg')

      paper.accept!

      get :status, :id => paper.sha, :format => :html

      etag2 = response.header['ETag']

      assert etag1 != etag2
      assert response.body.include?('accepted.svg')
    end

  end

  describe "PUT #update" do

    it "AS AUTHOR on pending paper should change title" do
      user = authenticate
      paper = create(:paper, :user => user)

      put :update, :id => paper.sha, :format => :json, :paper => { :title => "Boo ya!"}

      expect(response).to have_http_status(:success)
      assert_equal response_json["title"], "Boo ya!"
    end

    it "AS AUTHOR responds on submitted paper should not change title" do
      user = authenticate
      paper = create(:submitted_paper, :user => user, :title => "Hello space")

      put :update, :id => paper.sha, :format => :json, :paper => { :title => "Boo ya!"}

      expect(response.status).to eq(403)
      assert_equal "Hello space", paper.title
    end

  end

  describe "PUT #accept" do

    it "AS EDITOR responds successfully with a correct status and accept paper" do
      authenticate(:editor)
      paper = create(:paper_under_review)

      put :accept, :id => paper.sha, :format => :json

      expect(response).to have_http_status(:success)
      assert_equal response_json["state"], "accepted"
    end

    it "AS USER responds successfully with a correct status (403) and NOT accept paper" do
      authenticate
      paper = create(:paper_under_review)

      put :accept, :id => paper.sha, :format => :json

      # Should be redirected
      expect(response.status).to eq(403)
    end

    it "AS AUTHOR responds successfully with a correct status (403) and NOT accept paper" do
      user = authenticate
      paper = create(:paper_under_review, :user => user)

      put :accept, :id => paper.sha, :format => :json

      expect(response.status).to eq(403)
      assert response_json.empty?
    end

  end

  describe "GET #as_reviewer" do

    it "AS REVIEWER should return correct papers" do
      user = authenticate
      paper = create(:paper_under_review)
      create(:assignment_as_reviewer, :user => user, :paper => paper)

      get :as_reviewer, :format => :json

      expect(response).to have_http_status(:success)
      assert_equal 1, response_json.size
    end

  end

  describe "GET #as_reviewer" do

    context "with a state" do

      it "AS REVIEWER should return correct papers" do
        user = authenticate
        paper = create(:paper_under_review)
        create(:assignment_as_reviewer, :user => user, :paper => paper)

        get :as_reviewer, :format => :json, :state => 'pending'

        expect(response).to have_http_status(:success)
        assert_equal 0, response_json.size
      end

    end

  end

  describe "GET #as_author" do

    it "AS REVIEWER should return correct papers" do
      user = create(:user)
      paper = create(:paper_under_review)
      create(:assignment_as_reviewer, :user => user, :paper => paper)

      # This is the one that should be returned
      user = authenticate
      paper = create(:paper, :user => user)

      get :as_author, :format => :json

      expect(response).to have_http_status(:success)
      assert_equal 1, response_json.size
    end

  end

  describe "GET #as_editor" do

    it "AS EDITOR should return correct papers" do
      user = authenticate(:editor)
      create(:paper_under_review) # should be returned
      create(:submitted_paper) # should be returned
      create(:paper) # pending (should not be returned)

      get :as_editor, :format => :json

      expect(response).to have_http_status(:success)
      assert_equal 2, response_json.size
    end

  end

end
