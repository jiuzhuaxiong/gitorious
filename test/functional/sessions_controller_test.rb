# encoding: utf-8
#--
#   Copyright (C) 2007 Johan Sørensen <johan@johansorensen.com>
#   Copyright (C) 2008 August Lilleaas <augustlilleaas@gmail.com>
#   Copyright (C) 2008 Patrick Aljord <patcito@gmail.com>
#
#   This program is free software: you can redistribute it and/or modify
#   it under the terms of the GNU Affero General Public License as published by
#   the Free Software Foundation, either version 3 of the License, or
#   (at your option) any later version.
#
#   This program is distributed in the hope that it will be useful,
#   but WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#   GNU Affero General Public License for more details.
#
#   You should have received a copy of the GNU Affero General Public License
#   along with this program.  If not, see <http://www.gnu.org/licenses/>.
#++

require File.dirname(__FILE__) + '/../test_helper'

class SessionsControllerTest < ActionController::TestCase
  include OpenIdAuthentication
  
  def auth_token(token)
    CGI::Cookie.new('name' => 'auth_token', 'value' => token)
  end

  def cookie_for(user)
    auth_token users(user).remember_token
  end

  should " login and redirect" do
    @controller.stubs(:using_open_id?).returns(false)
    post :create, :email => "johan@johansorensen.com", :password => "test"
    assert_not_nil session[:user_id]
    assert_response :redirect
  end
 
  should " login with openid and redirect" do
    identity_url = "http://patcito.myopenid.com"
    @controller.stubs(:using_open_id?).returns(true)
    @controller.stubs(:successful?).returns(false)
    @controller.stubs(:authenticate_with_open_id).yields(
      Result[:successful], 
      identity_url, 
      registration = {
        'nickname' => "patcito",
        'email' => "patcito@gmail.com",
        'fullname' => 'Patrick Aljord'
      }
    )
    post :create, :openid_url => identity_url
    assert_not_nil !session[:user_id]
    assert_response :redirect
  end
   
  should " fail login and not redirect" do
    @controller.stubs(:using_open_id?).returns(false)
    post :create, :email => 'johan@johansorensen.com', :password => 'bad password'
    assert_nil session[:user_id]
    assert_response :success
  end
    
  should " logout" do
    login_as :johan
    get :destroy
    assert session[:user_id].nil?, 'nil? should be true'
    assert_response :redirect
  end
  
  should " remember me" do
    @controller.stubs(:using_open_id?).returns(false)
    post :create, :email => 'johan@johansorensen.com', :password => 'test', :remember_me => "1"
    assert_not_nil @response.cookies["auth_token"]
  end 
  
  should " should not remember me" do
    @controller.stubs(:using_open_id?).returns(false)
    post :create, :email => 'johan@johansorensen.com', :password => 'test', :remember_me => "0"
    assert_nil @response.cookies["auth_token"]
  end 
    
  should " delete token on logout" do
    login_as :johan
    get :destroy
    assert_nil @response.cookies["auth_token"]
  end
  
  should " login with cookie" do
    users(:johan).remember_me
    @request.cookies["auth_token"] = cookie_for(:johan)
    get :new
    assert @controller.send(:logged_in?)
  end
    
  should " fail when trying to login with with expired cookie" do
    users(:johan).remember_me
    users(:johan).update_attribute :remember_token_expires_at, 5.minutes.ago.utc
    @request.cookies["auth_token"] = cookie_for(:johan)
    get :new
    assert !@controller.send(:logged_in?)
  end
    
  should " fail cookie login" do
    users(:johan).remember_me
    @request.cookies["auth_token"] = auth_token('invalid_auth_token')
    get :new
    assert !@controller.send(:logged_in?)
  end
  
  should " set current user to the session user_id" do
    session[:user_id] = users(:johan).id
    get :new
    assert_equal users(:johan), @controller.send(:current_user)
  end
  
  should " show flash when invalid credentials are passed" do
    @controller.stubs(:using_open_id?).returns(false)
    post :create, :email => "invalid", :password => "also invalid"
    # response.body.should have_tag("div.flash_message", /please try again/)
    # rspec.should test(flash.now)
  end
  
  context 'Bypassing cachíng for authenticated users' do
    should 'be set when logging in' do
      post :create, :email => "johan@johansorensen.com", :password => "test"
      assert_not_nil cookies['authenticated']
    end
    
    should 'be removed when logging out' do
      post :create, :email => "johan@johansorensen.com", :password => "test"
      assert_not_nil cookies['authenticated']
      delete :destroy
      assert_nil cookies['authenticated']
    end
  end
end