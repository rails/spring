class SpinachExecutor
  def env(*)
    "test"
  end

  def exec_name
    "spinach"
  end
end

Spring.register_command "spinach", SpinachExecutor.new
