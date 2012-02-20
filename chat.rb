require 'rubygems'
require 'xmpp4r-simple'

class Chatter < Jabber::Simple
  def set_message_received_action(&block)
    client.add_message_callback do |message|
      block.call(message)
    end
  end
end

module  Chat
  
  class User
    attr_accessor :name, :jid
    def initialize(new_jid, new_name)
      self.jid = new_jid
      self.name = new_name.gsub("/", "//")
    end
  end  
  
  class Room
    attr_accessor :room, :users
    
    def initialize(email="chat.serve@gmail.com", password="chat.serve1", status_msg="ready")
      @room = Chatter.new(email, password, nil, status_msg)
      @room.set_message_received_action {process_incoming_messages}
      @room.accept_subscriptions = true
      @users = []
    end

    def invite(jid)
      @room.deliver jid, "You are invited to a chatroom with:\n" + user_names.join("\n")
    end

    def process_incoming_messages
      @room.new_subscriptions
      @room.received_messages do |msg|
        puts "#{msg.from} - #{msg.body}" if msg.type == :chat
        process_message(msg.from.to_s,msg.body) if msg.type == :chat
      end
    end

    private
    def process_message(from, message)
      from_jid = from[0...from.index("/")]
      if user_jids.include? from_jid
        from = user_jid(from_jid).name
      else
        from = from[0...from.index("@")]
      end
      message = check_for_command(message, from_jid, from)
      if message
        @users.each do |u|
          if u.jid != from_jid
            @room.deliver(u.jid, message)
          end
        end
      end
    end

    def check_for_command(message, from_jid, from)
      result = message
      if message[0,1] == "/"
        if !user_jids.include?(from_jid)
          #check for /join
          if message.grep(/^(\/join)/)
            if !user_jids.include? from_jid
              name = message.gsub(/^(\/join)/,'').strip
              if name.empty?
                name = from
              end
              @users.push User.new(from_jid, name)
              result = "#{name} has joined this room"
              @room.deliver(from_jid, result)
            else
              result = nil
              @room.deliver(from_jid, "you already joined!")
            end
          end 
        elsif user_jids.include? from_jid
          if !message.grep(/^(\/leave)/).empty?
            @users = @users.delete_if{|u| u.jid == from_jid}
            result = "#{from} left this room: " << message.gsub!(/^(\/leave)/, '')
            @room.deliver(from_jid, "you left!")
          elsif !message.grep(/^(\/list)/).empty?
            @room.deliver(from_jid, @users.map{|u| "#{u.name}: <#{u.jid}>"}.join("\n"))
            result = nil
          elsif !message.grep(/^(\/add)/).empty?
            invite(message.split(" ")[1])
            result = "#{from_jid} has invited: <#{message.split(" ")[1]}>"
          elsif !message.grep(/^(\/i)/).empty?
            result = from + " " + message.split(" ")[1..-1].join(" ")
            @room.deliver(from_jid, result)
          elsif !message.grep(/^(\/nick)/).empty?
            new_nick = message.split(" ")[1..-1].join(" ")
            user = @users.find {|x|x.jid == from_jid}
            old_nick = user.name.dup
            user.name = new_nick
            result = "#{old_nick} is now known as: #{user.name}"
            @room.deliver(from_jid, result)
          elsif !message.grep(/^(\/whois)/).empty?
            @room.deliver(from_jid, "#{message.split(" ")[1]} <#{@users.find {|u| u.name == message.split(" ")[1]}.jid rescue 'No such user'}>")
            result = nil
          else
            result = "#{from} says: " << message
          end
        end
     else
        result = nil
        send_basic_instructions(from_jid)
      end
      result
    end

    def send_basic_instructions(jid)
      message = "type '/join  your_name' "
      @room.deliver(jid, message)
    end

    def user_jids
      @users.map{|u| u.jid}
    end

    def user_names
      @users.map{|u| u.name}
    end

    def user_jid(jid)
      @users.find{|u| u.jid == jid}
    end
  end
  
end
