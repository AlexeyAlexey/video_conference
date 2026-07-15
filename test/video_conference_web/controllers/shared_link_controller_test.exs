defmodule VideoConferenceWeb.SharedLinkControllerTest do
  use VideoConferenceWeb.ConnCase

  import VideoConference.AccountsFixtures
  import VideoConference.TelephoneSwitchboard.SharedLinksFixtures
  import VideoConference.CustomCase
  import Ecto.Query, warn: false

  alias VideoConference.Repo
  alias VideoConference.TelephoneSwitchboard.SharedLinks.SharedLink

  setup %{conn: conn} do
    phone =
      create_phone_account(unique_phone(), generate_password())

    conn =
      conn
      |> put_req_header("accept", "application/json")
      |> log_in(phone)

    {:ok, conn: conn, phone: phone}
  end

  describe "list" do
    test "list", %{conn: conn, phone: phone} do
      create_shared_link(%{
        "phone_id" => phone.id,
        "name" => "Shared Link",
        "link_id" => "aaaaaaaaaaaaaaa",
        "password_required" => true,
        "password" => "password"
      })

      create_shared_link(%{
        "phone_id" => phone.id,
        "name" => "Shared Link 2",
        "link_id" => "bbbbbbbbbbbbbbbbb",
        "password_required" => false,
        "password" => nil
      })

      conn =
        get(conn, ~p"/shared_link/list", %{})

      assert [
               %{
                 "id" => id1,
                 "name" => "Shared Link",
                 "link_id" => link_id1,
                 "password_required" => true
               },
               %{
                 "id" => id2,
                 "name" => "Shared Link 2",
                 "link_id" => link_id2,
                 "password_required" => false
               }
             ] =
               json_response(conn, 200)

      assert id1
      assert id2
      assert link_id1
      assert link_id2
    end
  end

  describe "generate link" do
    test "link without passwor", %{conn: conn} do
      name = "Shared Link"

      conn =
        post(conn, ~p"/shared_link/generate", %{
          "name" => "Shared Link"
        })

      assert %{"id" => id, "name" => ^name, "link_id" => link_id, "password_required" => false} =
               json_response(conn, 200)

      assert link_id

      assert Repo.exists?(SharedLink, id: id)
    end

    test "link with password", %{conn: conn} do
      name = "Shared Link"

      conn =
        post(conn, ~p"/shared_link/generate", %{
          "name" => "Shared Link",
          "password" => "1234"
        })

      assert %{"id" => id, "name" => ^name, "link_id" => link_id, "password_required" => true} =
               json_response(conn, 200)

      assert link_id

      assert Repo.exists?(
               from s in SharedLink,
                 where: s.id == ^id and s.link_id == ^link_id and not is_nil(s.hashed_password)
             )
    end

    test "link id", %{conn: conn} do
      name = "Shared Link"

      conn =
        post(conn, ~p"/shared_link/generate", %{
          "name" => "Shared Link"
        })

      assert %{"id" => id, "name" => ^name, "link_id" => link_id, "password_required" => false} =
               json_response(conn, 200)

      shared_link = Repo.get!(SharedLink, id)

      assert shared_link.link_id == link_id
    end
  end

  describe "enable password" do
    setup %{conn: conn} do
      phone =
        create_phone_account(unique_phone(), generate_password())

      shared_link =
        create_shared_link(%{
          "phone_id" => phone.id,
          "name" => "Shared Link",
          "password_required" => false
        })

      conn =
        conn
        |> put_req_header("accept", "application/json")
        |> log_in(phone)

      {:ok, conn: conn, shared_link: shared_link}
    end

    test "enable password", %{conn: conn, shared_link: shared_link} do
      assert shared_link.password_required == false
      refute shared_link.hashed_password

      conn =
        post(conn, ~p"/shared_link/enable_password", %{
          "id" => shared_link.id,
          "password" => "password"
        })

      assert %{"id" => id, "password_required" => true} =
               json_response(conn, 200)

      assert Repo.exists?(
               from s in SharedLink,
                 where:
                   s.id == ^id and s.password_required == true and not is_nil(s.hashed_password)
             )
    end
  end

  describe "disable password" do
    setup %{conn: conn} do
      phone =
        create_phone_account(unique_phone(), generate_password())

      shared_link =
        create_shared_link(%{
          "phone_id" => phone.id,
          "name" => "Shared Link",
          "password_required" => true,
          "password" => "password"
        })

      conn =
        conn
        |> put_req_header("accept", "application/json")
        |> log_in(phone)

      {:ok, conn: conn, shared_link: shared_link}
    end

    test "disable password", %{conn: conn, shared_link: shared_link} do
      assert shared_link.password_required == true
      assert shared_link.hashed_password

      conn =
        post(conn, ~p"/shared_link/disable_password", %{
          "id" => shared_link.id
        })

      assert %{"id" => id, "password_required" => false} =
               json_response(conn, 200)

      assert Repo.exists?(
               from s in SharedLink,
                 where: s.id == ^id and s.password_required == false and is_nil(s.hashed_password)
             )
    end
  end

  describe "remove" do
    test "successfully", %{conn: conn, phone: phone} do
      shared_link =
        create_shared_link(%{
          "phone_id" => phone.id,
          "name" => "Shared Link",
          "link_id" => "aaaaaaaaaaaaaaa",
          "password_required" => true,
          "password" => "password"
        })

      conn =
        delete(conn, ~p"/shared_link/remove", %{"id" => shared_link.id})

      assert json_response(conn, 204) == nil

      refute Repo.exists?(SharedLink, id: shared_link.id)
    end

    test "not found", %{conn: conn} do
      assert delete(conn, ~p"/shared_link/remove", %{"id" => 2})
             |> json_response(404) == %{"errors" => %{"detail" => "Not Found"}}
    end
  end
end
