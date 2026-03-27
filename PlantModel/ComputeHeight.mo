within PlantModel;

block ComputeHeight "Converts a volume into an approximate height inside the cylindrical bowl"

  Modelica.Blocks.Interfaces.RealInput  volume "Volume of substance [m3]";
  Modelica.Blocks.Interfaces.RealOutput height "Approximate height in bowl [m]";

protected
  final constant Real pi     = Modelica.Constants.pi;
  final constant Real radius = (DIAMETER_BOWL_CM / 100.0) / 2.0 "Bowl inner radius [m]";

equation
  height = if radius > 0.0 then volume / (pi * radius * radius) else 0.0;

  annotation(Documentation(info="<html>
    <p>Approximates the height of a substance in the bowl assuming a perfect cylinder with
    diameter <em>DIAMETER_BOWL_CM</em>. Used by the visualisation panel.</p>
  </html>"));

end ComputeHeight;
